#!/bin/bash
set -eu                # Always put this in Bourne shell scripts
IFS="`printf '\n\t'`"  # Always put this in Bourne shell scripts

#Where the original .tif files are from aeronav
originalRastersDirectory="/media/sf_Apricorn/charts/aeronav.faa.gov/content/aeronav/wac_files/"

#Where the polygons for clipping are stored
clippingShapesDirectory="${HOME}/Documents/myPrograms/mergedCharts/clippingShapes/"

#For files that have a version in their name, this is where the links to the lastest version
#will be stored (step 1)
linkedRastersDirectory="${HOME}/Documents/myPrograms/mergedCharts/sourceRasters/wac/"

#Where expanded rasters are stored (step 2)
expandedRastersDirectory="${HOME}/Documents/myPrograms/mergedCharts/expandedRasters/wac/"

#Where clipped rasters are stored (step 3)
clippedRastersDirectory="${HOME}/Documents/myPrograms/mergedCharts/clippedRasters/wac/"

if [ ! -d $originalRastersDirectory ]; then
    echo "$originalRastersDirectory doesn't exist"
    exit
fi

if [ ! -d $linkedRastersDirectory ]; then
    echo "$linkedRastersDirectory doesn't exist"
    exit
fi

if [ ! -d $expandedRastersDirectory ]; then
    echo "$expandedRastersDirectory doesn't exist"
    exit
fi

if [ ! -d $clippedRastersDirectory ]; then
    echo "$clippedRastersDirectory doesn't exist"
    exit
fi


#Freshen the local files first

#Now unzip everything
cd $originalRastersDirectory
#Unzip all of the sectional charts
unzip -u -j "*.zip" "*.tif"

#Remove current links if any exist
#FILTER will be empty if no .tifs
FILTER=$(find $linkedRastersDirectory/ -type f \( -name "*.tif" \) )

if [ -z ${FILTER} ]; then
    echo "Deleting TIF links"
#     rm $linkedRastersDirectory/*.tif
fi


#Link latest revision of chart as a base name
shopt -s nullglob	
for f in *.tif
do
	#Replace spaces in name with _
	newName=($(printf $f | sed 's/\s/_/g'))

	#Strip off the series number
	newName=($(printf $newName | sed --regexp-extended 's/_[0-9]+\./\./ig'))

	#If names are sorted properly, this will link latest version
	echo "Linking $f -> $linkedRastersDirectory/$newName"
	ln -s -f -r "$f" $linkedRastersDirectory/$newName
done

Charts=(
CC-8_WAC CC-9_WAC CD-10_WAC CD-11_WAC CD-12_WAC CE-12_WAC CE-13_WAC CE-15_WAC CF-16_WAC CF-17_WAC
CF-18_WAC CF-19_WAC CG-18_WAC CG-19_WAC CG-20_WAC CG-21_WAC CH-22_WAC CH-23_WAC CH-24_WAC CH-25_WAC
CJ-26_WAC CJ-27_WAC
) 

#count of all items in chart array
ChartArrayLength=${#Charts[*]}

#data points for each entry
let points=1

#divided by size of each entry gives number of charts
let numberOfTacCharts=$ChartArrayLength/$points;

echo Found $numberOfTacCharts TAC charts

#Loop through all of the charts in our array and process them
for (( i=0; i<=$(( $numberOfTacCharts-1 )); i++ ))
  do
    #  if [-e $chartName*-warped.vrt ]
    #Pull the info for this chart from array
    sourceChartName=${Charts[i*$points+0]}

    #sourceChartName=ENR_A01_DCA
    expandedName=expanded-$sourceChartName
    clippedName=clipped-$expandedName
    
    #For now, just skip if this clipped raster already exists
    if [ -f "$clippedRastersDirectory/$clippedName.tif" ];
      then continue;
    fi

    #Test if we need to expand the original file
    if [ ! -f "$expandedRastersDirectory/$expandedName.tif" ];
      then
	echo --- Expand --- gdal_translate $sourceChartName
	
	gdal_translate \
		      -strict \
		      "$linkedRastersDirectory/$sourceChartName.tif" \
		      "$expandedRastersDirectory/$expandedName.tif"
      fi
    
    if [ ! -f "$clippingShapesDirectory/wac-$sourceChartName.shp" ];
      then
	echo ---No clipping shape found: "$clippingShapesDirectory/wac-$sourceChartName.shp"
	exit
    fi  
#	     -dstnodata 0 \
# -co "COMPRESS=LZW

    #Warp the original file, clipping it to it's clipping shape
    echo --- Clip --- gdalwarp $sourceChartName
    gdalwarp \
             -cutline "$clippingShapesDirectory/wac-$sourceChartName.shp" \
             -crop_to_cutline \
             -dstalpha \
             -of GTiff \
             -cblend 15 \
             -multi \
             -wo NUM_THREADS=ALL_CPUS  \
             -overwrite \
             -wm 1024 \
             -co TILED=YES \
             -co COMPRESS=DEFLATE \
             -co PREDICTOR=1 \
             -co ZLEVEL=9 \
             "$expandedRastersDirectory/$expandedName.tif" \
             "$clippedRastersDirectory/$clippedName.tif"
    
    #Create external overviews to make display faster in QGIS
    echo --- Add overviews --- gdaladdo $sourceChartName             
    gdaladdo \
             -ro \
             --config INTERLEAVE_OVERVIEW PIXEL \
             --config COMPRESS_OVERVIEW JPEG \
             --config BIGTIFF_OVERVIEW IF_NEEDED \
             "$clippedRastersDirectory/$clippedName.tif" \
             2 4 8 16         
             
    echo "----------------------------------------------------------"
    done
#!/bin/bash
# Backup important SoftWorx files

day=$(date +"%Y_%m_%d")
warpDir='~/Documents/Backup/Warp/'
warpBGR='$warpDir/WarpAlignParameters_BGR_$day.dat'
warpCYR='$warpDir/WarpAlignParameters_CYR_$day.dat'

echo "Backup up WarpAlignParameters to $warpDir..."
cp /home/worx/.softworx_OMX067SI/WarpAlignParameters_BGR.dat $warpBGR
cp /home/worx/.softworx_OMX067SI/WarpAlignParameters_CYR.dat $warpCYR
#!/bin/bash

WORKDIR=`pwd`
REF=/gscmnt/gc2802/halllab/sv_aggregate/refs/all_sequences.fa
EXCLUDE=/gscmnt/gc2802/halllab/sv_aggregate/exclusion/exclude.cnvnator_100bp.112015.bed
#SVTOOLS=/gscmnt/gc2802/halllab/sv_aggregate/repo/svtools
VAWK=/gscmnt/gc2719/halllab/bin/vawk
python --version
svtools --version
$VAWK --help
echo before comment
: <<'END'

#exit 0

# #Prepare computing environment
# 1. Python
# 2. svtools
# 3. vawk - copy vawk into demo directory or  (/usr/bin/vawk)?
# 4. CNVnator
# 5. Platform LSF

# #Prepare sample map file
# a sample map file has two columns
#
# sample_name,bam_path

##Use vawk to remove REF variants from full VCF 2016-04-27 jeldred

while read SAMPLE BAM
do
  echo $SAMPLE
  echo $BAM
  speedseq_project_dir=/gscmnt/gc2802/halllab/sv_aggregate/MISC/
  project_dir=/gscmnt/gc2801/analytics/jeldred/svtools_demo/
  #prepare output directory path
  mkdir -p $project_dir/lumpy/$SAMPLE
  # create non_ref vcf based on full vcf 
  zcat $speedseq_project_dir/lumpy/$SAMPLE/$SAMPLE.sv.vcf.gz \
  | $VAWK --header '{if(S$*$GT!="0/0" && S$*$GT!="./.") print $0}' \
  > $project_dir/lumpy/$SAMPLE/$SAMPLE.sv.non_ref.vcf
done < sample.map

#exit 0
## END

## Build and execute a shell command to concatenate and sort the variants 2016-04-27 jeldred

echo -n "svtools lsort " > sort_cmd.sh
while read SAMPLE BAM
do
  echo -ne " \\\\\n\t$project_dir/lumpy/$SAMPLE/$SAMPLE.sv.non_ref.vcf"
done >> sort_cmd.sh < sample.map

bash sort_cmd.sh | bgzip -c > sorted.vcf.gz

#exit 0
##END

## bsub lmerge sorted vcf 2016-04-27 jeldred
bsub -M 8000000 -q long -R 'select[mem>8000] rusage[mem=8000]' -e merge.err -o merge.out "zcat sorted.vcf.gz \
  | svtools lmerge -i /dev/stdin --product -f 20 \
  | bgzip -c > merged.vcf.gz "

#exit 0
##END

read  -n 1 -p "Wait for job to complete and enter C to continue"

## remove EBV (Epstein-Barr Virus) reads 2016-03-31 jeldred
zcat merged.vcf.gz \
| $VAWK --header '{if($0 !~ /NC_007605/) print $0}' \
| bgzip -c > merged.no_EBV.vcf.gz

#exit 0
##END

## bsub force genotypes with svtyper 2016-04-27 jeldred 
#this took about an hour in the long queue for most samples....one outlier NA12891 at 70 minutes

#/gscmnt/gc2719/halllab/bin/svtyper --help
#/gscmnt/gc2719/halllab/bin/vawk --help
#exit 0

while read SAMPLE BAM 
do 
  echo $SAMPLE
  mkdir -p gt/
  mkdir -p gt/logs/
  SPL=${BAM%.*}.splitters.bam
  bsub -M 30000000 -q long -R 'select[mem>30000] rusage[mem=30000]' -u jeldred@genome.wustl.edu -J $SAMPLE.gt -o gt/logs/$SAMPLE.gt.%J.log -e gt/logs/$SAMPLE.gt.%J.log \
    "zcat merged.no_EBV.vcf.gz \
     | $VAWK --header '{  \$6=\".\"; print }' \
     | svtools genotype \
       -B $BAM \
       -S $SPL \
     | sed 's/PR...=[0-9\.e,-]*\(;\)\{0,1\}\(\t\)\{0,1\}/\2/g' - \
     > gt/$SAMPLE.vcf"
done < sample.map

read  -n 1 -p "Wait for job to complete and enter C to continue"

#exit 0
##END

echo after comment

#ROOT libraries path 
#prepare directory structure
mkdir -p cn/logs/MISC
mkdir -p cn/MISC
# prepare environemnt for cnvnator
source /gsc/pkg/root/root/bin/thisroot.sh
# make uncompressed copy 
zcat merged.no_EBV.vcf.gz > merged.no_EBV.vcf
VCF=merged.no_EBV.vcf
# make coordinate file
create_coordinates -i $VCF -o coordinates

while read SAMPLE BAM
do
  base=`basename $BAM .bam`
  ROOT=/gscmnt/gc2802/halllab/sv_aggregate/MISC/lumpy/$SAMPLE/temp/cnvnator-temp/$base.bam.hist.root
  # cnvnator files were generated by speedseq that I did not run as part of this test, having used Haleys files as input 2016-04-27 jeldred

  #SM=`sambamba view -H $BAM | grep -m 1 "^@RG" | awk '{ for (i=1;i<=NF;++i) { if ($i~"^SM:") SM=$i; gsub("^SM:","",SM); } print SM }'`

echo SAMPLE $SAMPLE
#echo SM $SM

  bsub -M 4000000  -R 'select[mem>4000] rusage[mem=4000]' -u jeldred@genome.wustl.edubsub -q long -J $SAMPLE.cn -o cn/logs/$SAMPLE.cn.%J.log -e cn/logs/$SAMPLE.cn.%J.log \
     "svtools copynumber \
         --cnvnator /gscmnt/gc2719/halllab/bin/cnvnator-multi \
         -s $SAMPLE \
         -w 100 \
         -r $ROOT \
         -c coordinates \
         -v gt/$SAMPLE.vcf \
      > cn/$SAMPLE.vcf"
done < sample.map
#
read  -n 1 -p "Wait for job to complete and enter C to continue"
#exit 0
##END

## VCF paste 2016-04-27 jeldred
VCF=merged.no_EBV.vcf
bsub -M 4000000  -R 'select[mem>4000] rusage[mem=4000]' -u jeldred@genome.wustl.edubsub -q long -J paste.cn -o paste.cn.%J.log -e paste.cn.%J.log \
    "svtools vcfpaste \
        -m $VCF \
        -f cn.list \
        -q \
        | bgzip -c \
        > merged.sv.gt.cn.vcf.gz"
#

read  -n 1 -p "Wait for job to complete and enter C to continue"

#exit 0
##END


## Prune pipeline 2016-04-07 jeldred using files new new version of svtyper and the new prune, produced "expected" amount of pruning
#this is around the time I set my PYTHONPATH=/gscmnt/gc2802/halllab/sv_aggregate/repo/svtools
#set -o pipefail
svtools --version
bsub -q long -M 8000000 -R 'select[mem>8000] rusage[mem=8000]' "zcat merged.sv.gt.cn.vcf.gz \
| svtools afreq \
| svtools vcftobedpe \
| svtools bedpesort \
| svtools prune -s -d 100 -e \"AF\" \
| svtools bedpetovcf \
| bgzip -c > merged.sv.new_pruned.vcf.gz"
#
read  -n 1 -p "Wait for job to complete and enter C to continue"

#exit 0
##END
END
echo after comment

## Training 2016-04-07 jeldred
svtools --version

zcat merged.sv.new_pruned.vcf.gz \
 | svtools vcftobedpe  \
 | svtools varlookup -a stdin -b /gscmnt/gc2802/halllab/sv_aggregate/reclass/finmetseq.training_vars.bedpe.gz -c FINMETSEQ_HQ -d 50 \
 | svtools bedpetovcf \
 | $VAWK --header '{if(I$FINMETSEQ_HQ_AF>0) print $0}' \
 | bgzip -c > training.vars.vcf.gz

exit 0
##END

## Reclassify
svtools --version
zcat merged.sv.new_pruned.vcf.gz \
 | python /gscmnt/gc2802/halllab/sv_aggregate/dev/svtools/svtools/reclass_combined.py -g /gscmnt/gc2802/halllab/sv_aggregate/ceph_ped/ceph.sex.txt  -t <(zcat training.vars.vcf.gz)  -a /gscmnt/gc2719/halllab/users/cchiang/projects/g#tex/annotations/repeatMasker.recent.lt200millidiv.b37.sorted.bed.gz  -d class.diags.0313.txt  | bgzip -c > reclass.0313.all.vcf.gz

exit 0


#zcat reclass.0313.all.vcf.gz \
#| vawk --header '{
#  split(I$STRANDS,x,",");
#  split(x[1],y,":");
#  split(x[2],z,":");
#  if (I$SVTYPE=="DEL" || I$SVTYPE=="DUP" || I$SVTYPE=="MEI"){
#   $7="PASS"; print $0;
#  }  else if ( I$SVTYPE=="INV" && $8>=100 && (I$SR/I$SU)>=0.1 && (I$PE/I$SU)>=0.1 && (y[2]/I$SU)>0.1 && (z[2]/I$SU)>0.1){
#   $7="PASS"; print $0;
#  } else if ( I$SVTYPE=="BND" && $8>=100 && (I$SR/I$SU)>=0.25 && (I$PE/I$SU)>=0.25){
#   $7="PASS"; print $0;
#  } else {
#   $7="LOW"; print $0;
#  }
#}' | bgzip -c > reclassed.filtered.vcf.gz


exit 0


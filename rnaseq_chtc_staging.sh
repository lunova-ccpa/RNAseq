#!/bin/bash
# =============================================================================
# Complete RNA-seq Pipeline for CHTC (with Staging Area)
# Pulls from: /staging/groups/suresh_group/input/
# Pushes to:  /staging/groups/suresh_group/output/
# =============================================================================

set -e  # Exit on any error

# Job parameters
SAMPLE=$1
NUM_THREADS=${2:-4}
INDEX_PREFIX="mm39"
STAGING_IN="/staging/groups/suresh_group/input"
STAGING_OUT="/staging/groups/suresh_group/output"

echo "=========================================="
echo "Complete RNA-seq pipeline for: $SAMPLE"
echo "Threads: $NUM_THREADS"
echo "Pulling from: $STAGING_IN"
echo "Pushing to: $STAGING_OUT"
echo "=========================================="

# =============================================================================
# STEP 0: Check Input Files from Staging
# =============================================================================
Bootstrap: docker
From: condaforge/miniforge3:latest  # creating container recipe

%post
    # Setting up Bioconda
    conda config --add channels bioconda
    conda config --add channels conda-forge
    conda config --set channel_priority strict

    # Install packages directly
    conda install samtools hisat2 # 
# hello-world.sub
apptainer build hisat2.sif hisat2.def

mv hisat2.sif /staging/c/ccaguilar/hisat2.sif
  
container_image = osdf:///chtc/staging/c/ccaguilar/hisat2.sif #calling .sif files for each segment - create all of them at the begining 
shell = ./align.sh mm39 $sample #what condor is going to run once the job starts up 

log = align_$(Cluster)_$(Process).log
error = align_$(Cluster)_$(Process).err
output = align_$(Cluster)_$(Process).out
   
# Transfer our executable script
transfer_input_files = align.sh
   
# Requirements (e.g., operating system) your job needs, what amount of
# compute resources each job will need on the computer where it runs.
request_cpus = 8
request_memory = 32GB
request_disk = 50GB
   
# Run 3 instances of our job:
queue sample from listOfSamples.txt
echo ""
echo "[STEP 0] Checking input files in staging area..."

if [ ! -f "${STAGING_IN}/RawData/${SAMPLE}/${SAMPLE}_1.fq.gz" ]; then
  echo "ERROR: ${STAGING_IN}/RawData/${SAMPLE}/${SAMPLE}_1.fq.gz not found"
  exit 1
fi

if [ ! -f "${STAGING_IN}/RawData/${SAMPLE}/${SAMPLE}_2.fq.gz" ]; then
  echo "ERROR: ${STAGING_IN}/RawData/${SAMPLE}/${SAMPLE}_2.fq.gz not found"
  exit 1
fi

echo "✓ Raw FASTQ files found in staging area"

# Check for index files and annotation in staging
if [ ! -f "${STAGING_IN}/mm39.1.ht2" ]; then
  echo "ERROR: HISAT2 index files not found in staging: ${STAGING_IN}"
  exit 1
fi

if [ ! -f "${STAGING_IN}/Mus_musculus.GRCm39.112.gtf" ]; then
  echo "ERROR: GTF annotation not found in staging: ${STAGING_IN}"
  exit 1
fi

if [ ! -f "${STAGING_IN}/grcm39.fa" ]; then
  echo "ERROR: Genome FASTA not found in staging: ${STAGING_IN}"
  exit 1
fi

echo "✓ All reference files found in staging area"

# =============================================================================
# STEP 0b: Copy Files from Staging to Local Working Directory
# =============================================================================

echo ""
echo "[STEP 0b] Copying files from staging to local working directory..."

# Copy reference files to current working directory
cp ${STAGING_IN}/mm39.*.ht2 .
cp ${STAGING_IN}/Mus_musculus.GRCm39.112.gtf .
cp ${STAGING_IN}/grcm39.fa .

echo "✓ Reference files copied to local job directory"

# =============================================================================
# STEP 1: Trim with fastp
# =============================================================================

echo ""
echo "[STEP 1] Trimming with fastp..."
echo "Command: fastp -i ${STAGING_IN}/RawData/${SAMPLE}/${SAMPLE}_1.fq.gz -I ${STAGING_IN}/RawData/${SAMPLE}/${SAMPLE}_2.fq.gz -o ${SAMPLE}_1.trimmed.fq.gz -O ${SAMPLE}_2.trimmed.fq.gz -w ${NUM_THREADS} -q 15 -u 40"

fastp \
  -i ${STAGING_IN}/RawData/${SAMPLE}/${SAMPLE}_1.fq.gz \
  -I ${STAGING_IN}/RawData/${SAMPLE}/${SAMPLE}_2.fq.gz \
  -o ${SAMPLE}_1.trimmed.fq.gz \
  -O ${SAMPLE}_2.trimmed.fq.gz \
  -w ${NUM_THREADS} \
  -q 15 \
  -u 40 \
  --html ${SAMPLE}_fastp.html \
  --json ${SAMPLE}_fastp.json

TRIM_STATUS=$?
echo "fastp trimming completed with status: $TRIM_STATUS"
echo "Trimming results saved to ${SAMPLE}_fastp.json"

# ======================================================================================
# STEP 2: Align with HISAT2
# ======================================================================================
INDEX_PREFIX="$1"
SAMPLE="$2"
echo ""
echo "[STEP 2] Running HISAT2 alignment..."
echo "Command: hisat2 -x ${INDEX_PREFIX} -1 ${SAMPLE}_1.trimmed.fq.gz -2 ${SAMPLE}_2.trimmed.fq.gz -S ${SAMPLE}.sam -p 8"

hisat2 -x ${INDEX_PREFIX} \
  -1 ${SAMPLE}_1.trimmed.fq.gz \
  -2 ${SAMPLE}_2.trimmed.fq.gz \
  -S ${SAMPLE}.sam \
  -p 8

ALIGN_STATUS=$?
echo "HISAT2 alignment completed with status: $ALIGN_STATUS"


# =========================================================================================
# STEP 3: Convert SAM to BAM
# =========================================================================================

echo ""
echo "[STEP 3] Converting SAM to BAM..."
echo "Command: samtools view -bS ${SAMPLE}.sam -o ${SAMPLE}.bam"

samtools view -bS ${SAMPLE}.sam -o ${SAMPLE}.bam

# Remove SAM file to save space
rm -f ${SAMPLE}.sam
echo "SAM→BAM conversion complete. Removed SAM file."

# =========================================================================================
# STEP 4: Sort BAM
# =========================================================================================

echo ""
echo "[STEP 4] Sorting BAM file..."
echo "Command: samtools sort -@ ${NUM_THREADS} -o ${SAMPLE}.sorted.bam ${SAMPLE}.bam"

samtools sort -@ ${NUM_THREADS} -o ${SAMPLE}.sorted.bam ${SAMPLE}.bam

# Remove unsorted BAM
rm -f ${SAMPLE}.bam
echo "BAM sorting complete."

# =========================================================================================
# STEP 5: Index BAM
# =========================================================================================

echo ""
echo "[STEP 5] Indexing sorted BAM..."
echo "Command: samtools index ${SAMPLE}.sorted.bam"

samtools index ${SAMPLE}.sorted.bam
echo "BAM indexing complete."

# =========================================================================================
# STEP 6: featureCounts Gene Counting
# =========================================================================================

echo ""
echo "[STEP 6] Running featureCounts..."
echo "Command: featureCounts -T ${NUM_THREADS} -p -a Mus_musculus.GRCm39.112.gtf -o ${SAMPLE}_counts.txt ${SAMPLE}.sorted.bam"

featureCounts -T ${NUM_THREADS} \
  -p \
  -a Mus_musculus.GRCm39.112.gtf \
  -o ${SAMPLE}_counts.txt \
  ${SAMPLE}.sorted.bam

echo "featureCounts complete."

# =========================================================================================
# STEP 7: Move Results to Staging Output
# =========================================================================================

echo ""
echo "[STEP 7] Moving results to staging output area..."
echo "Destination: ${STAGING_OUT}/${SAMPLE}/"

# Create output directory if it doesn't exist
mkdir -p ${STAGING_OUT}/${SAMPLE}/

# Move all output files
mv ${SAMPLE}.sorted.bam ${STAGING_OUT}/${SAMPLE}/
mv ${SAMPLE}.sorted.bam.bai ${STAGING_OUT}/${SAMPLE}/
mv ${SAMPLE}_counts.txt ${STAGING_OUT}/${SAMPLE}/
mv ${SAMPLE}_counts.txt.summary ${STAGING_OUT}/${SAMPLE}/
mv ${SAMPLE}_fastp.json ${STAGING_OUT}/${SAMPLE}/
mv ${SAMPLE}_fastp.html ${STAGING_OUT}/${SAMPLE}/

echo "✓ All results moved to staging output"

# =========================================================================================
# Summary
# =========================================================================================

echo ""
echo "=========================================="
echo "Complete pipeline finished for $SAMPLE"
echo ""
echo "Output files in: ${STAGING_OUT}/${SAMPLE}/"
ls -lh ${STAGING_OUT}/${SAMPLE}/
echo ""
echo "All steps complete!"
echo "=========================================="

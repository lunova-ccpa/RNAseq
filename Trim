cat > Trim.sh << 'EOF'
#!/bin/bash

# TRIM.SH - Trimmomatic PE trimming
# Takes SAMPLE as argument

SAMPLE="$1"
STAGING_IN="/staging/c/ccaguilar"
NUM_THREADS=4

echo ""
echo "[TRIM] Processing sample: $SAMPLE"
echo "Input: ${STAGING_IN}/RawData/${SAMPLE}_1.fq.gz, ${STAGING_IN}/RawData/${SAMPLE}_2.fq.gz"

trimmomatic PE -threads ${NUM_THREADS} -phred33 \
  ${STAGING_IN}/RawData/${SAMPLE}_1.fq.gz \
  ${STAGING_IN}/RawData/${SAMPLE}_2.fq.gz \
  ${SAMPLE}_1.paired.trimmed.fq.gz \
  ${SAMPLE}_1.unpaired.trimmed.fq.gz \
  ${SAMPLE}_2.paired.trimmed.fq.gz \
  ${SAMPLE}_2.unpaired.trimmed.fq.gz \
  ILLUMINACLIP:${STAGING_IN}/TruSeq3-PE.fa:2:30:10 \
  LEADING:3 TRAILING:3 SLIDINGWINDOW:4:15 MINLEN:36

TRIM_STATUS=$?
echo "Trimmomatic completed with status: $TRIM_STATUS"

if [ $TRIM_STATUS -ne 0 ]; then
  echo "ERROR: Trimmomatic failed for $SAMPLE"
  exit 1
fi

# Keep only paired-end reads, remove unpaired
rm ${SAMPLE}_1.unpaired.trimmed.fq.gz ${SAMPLE}_2.unpaired.trimmed.fq.gz

# Rename to match align.sh expectations
mv ${SAMPLE}_1.paired.trimmed.fq.gz ${SAMPLE}_1.trimmed.fq.gz
mv ${SAMPLE}_2.paired.trimmed.fq.gz ${SAMPLE}_2.trimmed.fq.gz

echo "✓ Trimming complete for $SAMPLE"
EOF

chmod +x Trim.sh

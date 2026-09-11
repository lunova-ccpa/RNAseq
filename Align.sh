cat > Align.sh << 'EOF'
#!/bin/bash

# ALIGN.SH - HISAT2 alignment, SAM→BAM, and featureCounts
# Arguments: $1 = INDEX_PREFIX (mm39), $2 = SAMPLE

INDEX_PREFIX="$1"
SAMPLE="$2"
STAGING_IN="/staging/c/ccaguilar"
STAGING_OUT="/staging/c/ccaguilar/output"
NUM_THREADS=8

mkdir -p ${STAGING_OUT}

echo ""
echo "[ALIGN] HISAT2 alignment for $SAMPLE"
hisat2 -x ${STAGING_IN}/${INDEX_PREFIX} \
  -1 ${SAMPLE}_1.trimmed.fq.gz \
  -2 ${SAMPLE}_2.trimmed.fq.gz \
  -S ${SAMPLE}.sam \
  -p ${NUM_THREADS}

ALIGN_STATUS=$?
if [ $ALIGN_STATUS -ne 0 ]; then
  echo "ERROR: HISAT2 alignment failed"
  exit 1
fi

echo ""
echo "[SAM→BAM] Converting SAM to BAM"
samtools view -bS ${SAMPLE}.sam -o ${SAMPLE}.bam
rm -f ${SAMPLE}.sam

echo ""
echo "[SORT] Sorting BAM"
samtools sort -@ ${NUM_THREADS} -o ${SAMPLE}.sorted.bam ${SAMPLE}.bam
rm -f ${SAMPLE}.bam

echo ""
echo "[INDEX] Indexing BAM"
samtools index ${SAMPLE}.sorted.bam

echo ""
echo "[COUNTS] Running featureCounts"
featureCounts -T ${NUM_THREADS} \
  -p \
  -a ${STAGING_IN}/Mus_musculus.GRCm39.112.gtf \
  -o ${SAMPLE}_counts.txt \
  ${SAMPLE}.sorted.bam

echo ""
echo "[OUTPUT] Moving results to staging output"
mkdir -p ${STAGING_OUT}/${SAMPLE}/
mv ${SAMPLE}.sorted.bam ${STAGING_OUT}/${SAMPLE}/
mv ${SAMPLE}.sorted.bam.bai ${STAGING_OUT}/${SAMPLE}/
mv ${SAMPLE}_counts.txt ${STAGING_OUT}/${SAMPLE}/
mv ${SAMPLE}_counts.txt.summary ${STAGING_OUT}/${SAMPLE}/

echo "✓ Complete pipeline finished for $SAMPLE"
echo "Results in: ${STAGING_OUT}/${SAMPLE}/"
EOF

chmod +x Align.sh

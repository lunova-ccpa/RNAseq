# Complete RNA-seq Pipeline for CHTC

**All 18 samples:** Trimming + Alignment + Gene Counting via Staging 

## **What This Pipeline Does**
Per sample (A1-A18):
  
1. **Trim** raw FASTQs with fastp 
- Removes adapters, low-quality bases
- Generates QC report

2. **Align** trimmed reads to GRCm39 with HISAT2 

3. **Convert & Sort** SAM → BAM 
- samtools handles format conversion and sorting

4. **Count** reads per gene with featureCounts
- 57k genes × 18 samples count matrix

---
  
  ## **File Flow**
  
  ```
Your Mac
↓ (Globus)
/staging/groups/suresh_group/input/
  ├── RawData/  (all 18 samples)
├── mm39.*.ht2  (HISAT2 index)
├── Mus_musculus.GRCm39.112.gtf
└── grcm39.fa

↓ (CHTC reads from here)

CHTC Cluster (runs jobs)
- Trim (fastp)
- Align (HISAT2)
- Count (featureCounts)

↓ (CHTC writes to here)

/staging/groups/suresh_group/output/
  ├── A1/
  │   ├── A1.sorted.bam
│   ├── A1.sorted.bam.bai
│   ├── A1_counts.txt
│   ├── A1_counts.txt.summary
│   └── A1_fastp.json
├── A2/
  └── ... through A18/
  
  ↓ (Globus)

Your Mac (results back)
```

---
  ## **PHASE 1: Prepare Staging Input Directory**
  
  ### **1a. Create Input Directory Structure (on CHTC)**
  
  ```bash
# SSH to CHTC
ssh your_username@submit-1.chtc.wisc.edu

# Create staging input directory
mkdir -p /staging/groups/suresh_group/input
mkdir -p /staging/groups/suresh_group/output

# Check permissions
ls -ld /staging/groups/suresh_group/
  ```

### **1b. Transfer Files to Staging via Globus**

**What to transfer:**
  - `RawData/` (all raw FASTQ files)
- `mm39.1.ht2` through `mm39.8.ht2` (HISAT2 index)
- `Mus_musculus.GRCm39.112.gtf` (annotation)
- `grcm39.fa` (genome)

**How:**
  1. Open Globus: https://app.globus.org/
  2. **Left panel (Source):** Your Mac endpoint → `~/Desktop/rnaseq_analysis/`
3. **Right panel (Destination):** CHTC endpoint → `/staging/groups/suresh_group/input/`
4. Transfer all 4 items to staging

**Verify on CHTC:**
  ```bash
ssh your_username@submit-1.chtc.wisc.edu
ls /staging/groups/suresh_group/input/
  # Should show: RawData/, mm39.*.ht2, Mus_musculus.GRCm39.112.gtf, grcm39.fa
  ```
## **PHASE 2: Submit Jobs**

### **2a. SSH to CHTC**

```bash
ssh your_username@submit-1.chtc.wisc.edu
```

### **2b. Go to Your Submission Directory**

```bash
# You could be anywhere; let's use a clean directory
mkdir -p ~/rnaseq_submission_staging
cd ~/rnaseq_submission_staging
```

### **2c. Copy Submit Script Here**

You need:
  - `rnaseq_chtc_staging.sh` (the pipeline script)
- `rnaseq_chtc_staging.submit` (the HTCondor submit file)

Either:
  - Copy from your Mac via SCP:
  ```bash
scp your_mac_username@your_mac.local:~/path/to/rnaseq_chtc_staging.* .
```
- Or re-create them on CHTC from the files provided

### **2d. Make Script Executable**

```bash
chmod +x rnaseq_chtc_staging.sh
```

### **2e. Submit Jobs**

```bash
condor_submit rnaseq_chtc_staging.submit
```

Expected output:
  ```
Submitting job(s)..............................
18 job(s) submitted to cluster 12345.
```

---
  ## **PHASE 3: Monitor Jobs**
  
  ### **Check Status**
  ```bash
condor_q
```

### **Watch Specific Job**
```bash
tail -f rnaseq_staging_12345_0.log
```

### **Check Staging Output**
```bash
# As jobs complete, results appear in staging
ls /staging/groups/suresh_group/output/
  
  # After first job (A1) completes:
  ls /staging/groups/suresh_group/output/A1/
  # Should show: A1.sorted.bam, A1_counts.txt, etc.
  ```

### **Expected Timeline**
- **Per sample:** 3-4 hours
- **Total (18 in parallel):** 3-4 hours
- **Job starts:** immediately
- **Job completes:** ~3-4 hours later

---
  
  ## **PHASE 4: Transfer Results Back via Globus**
  
  Once jobs complete:
  
  1. Go to: https://app.globus.org/
  2. **Left panel (Source):** CHTC endpoint → `/staging/groups/suresh_group/output/`
3. **Right panel (Destination):** Your Mac endpoint → `~/Desktop/rnaseq_analysis/results_staging/`
4. Transfer everything

### **4a. Use Globus to Transfer Results Back**

Once jobs complete:
  
  1. Go to: https://app.globus.org/
  2. **Left panel (Source):** CHTC endpoint → `/staging/groups/suresh_group/output/`
3. **Right panel (Destination):** Your Mac endpoint → `~/Desktop/rnaseq_analysis/results_staging/`
4. Transfer everything

### **4b. Verify on Your Mac**

```bash
ls ~/Desktop/rnaseq_analysis/results_staging/
  # Should show: A1/, A2/, A3/, ... A18/
  
  ls ~/Desktop/rnaseq_analysis/results_staging/A1/
  # Should show: A1.sorted.bam, A1_counts.txt, etc.
  ```

---

  ## **Pre-Submission Setup**
  
  ### 1. **Verify You Have Raw Data**
  
  ```bash
# Check that RawData/ directory exists with all 18 samples
  ls RawData/
# Should show: A1/ A2/ A3/ ... A18/
  
# Verify each sample has 2 files
  ls RawData/A1/
# Should show: A1_1.fq.gz A1_2.fq.gz
  ```

 
   ### 2. **Verify HISAT2 Index Files**
  
  ```bash
  ls -lh mm39.*.ht2
# Should show all 8 files (889M, 664M, 664M, 1.2G, 676M, etc.)
  ```
  
  
  ### 3. **Verify GTF Annotation**
  
  ```bash
  ls -lh Mus_musculus.GRCm39.112.gtf
# Should be ~880M
  ```
 
  
  ### 4. **Verify Genome FASTA**
  
  ```bash
  ls -lh grcm39.fa
# Should be ~2.6G
  ```
  
  ### 5. **Make Script Executable**
  
  ```bash
  chmod +x rnaseq_chtc_complete.sh
  ```
  
  ### 6. **Create Results Directory**
  
  ```bash
  mkdir -p results
  ```
  
  ### 7. **Check Your Working Directory**
  
  ```bash
  pwd
  ls -lh
  ```
  
 # Should show:
    ```
  rnaseq_chtc_complete.sh
  rnaseq_chtc_complete.submit
  RawData/
    mm39.*.ht2
  Mus_musculus.GRCm39.112.gtf
  grcm39.fa
  results/
    ```

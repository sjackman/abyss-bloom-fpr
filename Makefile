# Effect of Bloom filter false positive rate on assembly with ABySS

SHELL=bash -e -o pipefail
ifeq ($(shell zsh -e -o pipefail -c 'true' 2>/dev/null; echo $$?), 0)
# Set pipefail to ensure that all commands of a pipe succeed.
SHELL=zsh -e -o pipefail
# Report run time and memory usage with zsh.
export REPORTTIME=1
export TIMEFMT=time user=%U system=%S elapsed=%E cpu=%P memory=%M job=%J
endif

# Record run time and memory usage in a file using GNU time.
ifneq ($(shell command -v gtime),)
time=command gtime -v -o $@.time
else
time=command time -v -o $@.time
endif

.DELETE_ON_ERROR:
.SECONDARY:

all: fpr.png

# Download the reference.
reference.fa:
	curl -L -o $@ https://github.com/rrwick/Unicycler/raw/master/sample_data/reference.fasta

# Download the data, read 1.
short_reads_1.fq.gz:
	curl -L -o $@ https://github.com/rrwick/Unicycler/raw/master/sample_data/short_reads_1.fq.gz

# Download the data, read 2.
short_reads_2.fq.gz:
	curl -L -o $@ https://github.com/rrwick/Unicycler/raw/master/sample_data/short_reads_2.fq.gz

# Merge paired-end reads.
plasmids.fq: short_reads_1.fq.gz short_reads_2.fq.gz
	seqtk mergepe $^ >$@

# Assemble the reads using ABySS 2.0.
B%-1.fa: plasmids.fq
	$(time) abyss-pe k=88 H=1 B=$* name=B$* in=$< v=-v $@ >$@.log 2>&1

# Aggregate results of assembly metrics.
abyss-fac.tsv: \
		B500000-1.fa B510000-1.fa B520000-1.fa B530000-1.fa B540000-1.fa \
		B550000-1.fa B560000-1.fa B570000-1.fa B580000-1.fa B590000-1.fa \
		B600000-1.fa B620000-1.fa B640000-1.fa B660000-1.fa B680000-1.fa \
		B700000-1.fa B750000-1.fa B800000-1.fa B850000-1.fa B900000-1.fa B950000-1.fa B1000000-1.fa
	abyss-fac -G229880 $^ >$@

# Aggregate results of FPR.
abyss-fpr.tsv: \
		B500000-1.fa.log B510000-1.fa.log B520000-1.fa.log B530000-1.fa.log B540000-1.fa.log \
		B550000-1.fa.log B560000-1.fa.log B570000-1.fa.log B580000-1.fa.log B590000-1.fa.log \
		B600000-1.fa.log B620000-1.fa.log B640000-1.fa.log B660000-1.fa.log B680000-1.fa.log \
		B700000-1.fa.log B750000-1.fa.log B800000-1.fa.log B850000-1.fa.log B900000-1.fa.log B950000-1.fa.log B1000000-1.fa.log
	awk 'BEGIN { print "B\tFPR" } /^Bloom filter FPR/ { B = FILENAME; gsub("B|-1.fa.log", "", B); FPR = $$4; sub("%", "", FPR); print B "\t" FPR }' $^ | sort -k1,1n >$@

# Plot the assembly metrics vs. FPR.
fpr.png: abyss-fac.tsv abyss-fpr.tsv fpr.rmd
	Rscript -e 'rmarkdown::render("fpr.rmd", "html_document", "fpr.html")'

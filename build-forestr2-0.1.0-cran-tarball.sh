#!/usr/bin/env bash
#
# build-forestr-cran-tarball.sh
#
# Produces the official CRAN submission tarball for forestr2 0.1.0
# by running `R CMD build` on the package source.
#
# This script MUST be run on the maintainer's local machine where R is
# installed. The sandbox cannot run R CMD build because R is not
# installed there.
#
# Usage:
#   chmod +x build-forestr-cran-tarball.sh
#   ./build-forestr-cran-tarball.sh
#
# Or run the commands manually one-by-one (see Step 5 below).
#
# Output:
#   ./forestr2_0.1.0.tar.gz   <- the official CRAN submission tarball
#                                     (created by R CMD build, includes
#                                      inst/doc/forestr-workflow.html)
#
# After this script runs, upload forestr2_0.1.0.tar.gz to:
#   https://CRAN.R-project.org/submit.html
#
set -euo pipefail

# ----------------------------------------------------------------------------
# Configuration
# ----------------------------------------------------------------------------
PACKAGE_NAME="forestr2"
PACKAGE_VERSION="0.1.0"
EXPECTED_TARBALL="${PACKAGE_NAME}_${PACKAGE_VERSION}.tar.gz"
SOURCE_TARBALL="${PACKAGE_NAME}_${PACKAGE_VERSION}.tar.gz"  # sandbox-built
WORK_DIR="$(pwd)/cran-build-work"
FINAL_TARBALL="$(pwd)/${EXPECTED_TARBALL}"

# ----------------------------------------------------------------------------
# Step 0: Pre-flight checks
# ----------------------------------------------------------------------------
echo "============================================================"
echo "  forestr ${PACKAGE_VERSION} — CRAN tarball builder"
echo "============================================================"
echo ""
echo "Step 0: Pre-flight checks"
echo "------------------------------------------------------------"

# Check R is installed
if ! command -v R >/dev/null 2>&1; then
    echo "ERROR: R is not installed or not in PATH."
    echo "       Install R from https://cran.r-project.org/"
    echo "       On Windows: also install Rtools from"
    echo "       https://cran.r-project.org/bin/windows/Rtools/"
    exit 1
fi
R_VERSION=$(R --version | head -1 | awk '{print $3}')
echo "  [OK] R version: ${R_VERSION}"

# Check Rscript is installed
if ! command -v Rscript >/dev/null 2>&1; then
    echo "ERROR: Rscript is not installed or not in PATH."
    exit 1
fi
echo "  [OK] Rscript available"

# Check the source tarball exists
if [ ! -f "${SOURCE_TARBALL}" ]; then
    echo "ERROR: Source tarball not found: ${SOURCE_TARBALL}"
    echo ""
    echo "       Download forestr_${PACKAGE_VERSION}.tar.gz from"
    echo "       /home/z/my-project/download/ on the sandbox and"
    echo "       place it in the current directory before running"
    echo "       this script."
    exit 1
fi
echo "  [OK] Source tarball: ${SOURCE_TARBALL}"

# Check pandoc is installed (needed for vignette building)
if ! command -v pandoc >/dev/null 2>&1; then
    echo "WARNING: pandoc is not installed."
    echo "         The vignette may fail to build without pandoc."
    echo "         Install pandoc from https://pandoc.org/installing.html"
fi

echo ""
echo "  [OK] All pre-flight checks passed."
echo ""

# ----------------------------------------------------------------------------
# Step 1: Clean up any previous build artifacts
# ----------------------------------------------------------------------------
echo "Step 1: Cleaning up previous build artifacts"
echo "------------------------------------------------------------"
rm -rf "${WORK_DIR}"
mkdir -p "${WORK_DIR}"
echo "  [OK] Work directory: ${WORK_DIR}"
echo ""

# ----------------------------------------------------------------------------
# Step 2: Unpack the source tarball
# ----------------------------------------------------------------------------
echo "Step 2: Unpacking source tarball"
echo "------------------------------------------------------------"
cd "${WORK_DIR}"
tar -xzf "../${SOURCE_TARBALL}"
if [ -d "${PACKAGE_NAME}_${PACKAGE_VERSION}" ]; then
    SOURCE_DIR="${PACKAGE_NAME}_${PACKAGE_VERSION}"
elif [ -d "${PACKAGE_NAME}" ]; then
    SOURCE_DIR="${PACKAGE_NAME}"
else
    echo "ERROR: Unpacked package directory not found"
    exit 1
fi
cd "${SOURCE_DIR}"
echo "  [OK] Unpacked to: ${WORK_DIR}/${PACKAGE_NAME}_${PACKAGE_VERSION}"
echo ""

# ----------------------------------------------------------------------------
# Step 3: Verify package structure
# ----------------------------------------------------------------------------
echo "Step 3: Verifying package structure"
echo "------------------------------------------------------------"
for required_file in DESCRIPTION NAMESPACE LICENSE R/volume.R R/biomass.R \
                     R/inventory.R R/yield-models.R R/statistics.R \
                     R/utils.R R/forestr2-package.R \
                     tests/testthat.R vignettes/forestr-workflow.Rmd \
                     inst/CITATION man/; do
    if [ ! -e "${required_file}" ]; then
        echo "ERROR: Missing required file: ${required_file}"
        exit 1
    fi
done
echo "  [OK] All required files present"

# Verify DESCRIPTION version matches
DESC_VERSION=$(grep "^Version:" DESCRIPTION | awk '{print $2}')
if [ "${DESC_VERSION}" != "${PACKAGE_VERSION}" ]; then
    echo "ERROR: DESCRIPTION version (${DESC_VERSION}) does not match expected (${PACKAGE_VERSION})"
    exit 1
fi
echo "  [OK] DESCRIPTION version: ${DESC_VERSION}"

# Verify maintainer
MAINTAINER=$(grep "^Maintainer:" DESCRIPTION)
echo "  [OK] Maintainer: ${MAINTAINER}"
echo ""

# ----------------------------------------------------------------------------
# Step 4: Install Suggests packages needed for vignette building
# ----------------------------------------------------------------------------
echo "Step 4: Installing required R packages (knitr, rmarkdown, roxygen2)"
echo "------------------------------------------------------------"
Rscript -e '
if (!requireNamespace("knitr",     quietly = TRUE)) install.packages("knitr",     repos = "https://cloud.r-project.org/")
if (!requireNamespace("rmarkdown", quietly = TRUE)) install.packages("rmarkdown", repos = "https://cloud.r-project.org/")
if (!requireNamespace("roxygen2",  quietly = TRUE)) install.packages("roxygen2",  repos = "https://cloud.r-project.org/")
if (!requireNamespace("ggplot2",   quietly = TRUE)) install.packages("ggplot2",   repos = "https://cloud.r-project.org/")
cat("\n[OK] All required R packages installed.\n")
'
echo ""

# ----------------------------------------------------------------------------
# Step 5: Regenerate man/ and NAMESPACE with real roxygen2
# ----------------------------------------------------------------------------
echo "Step 5: Regenerating man/ and NAMESPACE with real roxygen2"
echo "------------------------------------------------------------"
Rscript -e '
roxygen2::roxygenize(".", roclets = c("namespace", "rd"))
cat("\n[OK] roxygen2 regeneration complete.\n")
'
echo ""

# ----------------------------------------------------------------------------
# Step 6: Run R CMD build (THIS produces the official CRAN tarball)
# ----------------------------------------------------------------------------
echo "Step 6: Running R CMD build"
echo "------------------------------------------------------------"
echo "  This will:"
echo "    - Build the vignette (knitr::knit on forestr-workflow.Rmd)"
echo "    - Place built vignette in inst/doc/forestr-workflow.html"
echo "    - Create/update the MD5 file"
echo "    - Clean stray files (*.so, *.o, .Rproj.user/, etc.)"
echo "    - Produce ${EXPECTED_TARBALL} in the parent directory"
echo ""
cd ..
R CMD build "${SOURCE_DIR}"
cd "${SOURCE_DIR}"
if [ ! -f "../${EXPECTED_TARBALL}" ]; then
    echo "ERROR: R CMD build did not produce ${EXPECTED_TARBALL}"
    exit 1
fi
echo ""
echo "  [OK] R CMD build produced: ${EXPECTED_TARBALL}"
echo ""

# ----------------------------------------------------------------------------
# Step 7: Verify the built tarball has the vignette in inst/doc/
# ----------------------------------------------------------------------------
echo "Step 7: Verifying built tarball structure"
echo "------------------------------------------------------------"
cd ..
echo "  Tarball contents (key files):"
tar -tzf "${EXPECTED_TARBALL}" | grep -E "(inst/doc/|MD5|DESCRIPTION|NAMESPACE|vignettes/)" | sort
echo ""

if ! tar -tzf "${EXPECTED_TARBALL}" | grep -q "inst/doc/forestr-workflow.html"; then
    echo "ERROR: Built tarball does NOT contain inst/doc/forestr-workflow.html"
    echo "       The vignette did not build. Check the R CMD build output above."
    exit 1
fi
echo "  [OK] Built vignette present: inst/doc/forestr-workflow.html"

if ! tar -tzf "${EXPECTED_TARBALL}" | grep -q "^${PACKAGE_NAME}_${PACKAGE_VERSION}/MD5$"; then
    echo "WARNING: MD5 file not found in tarball (R CMD build may have skipped it)"
fi
echo ""

# ----------------------------------------------------------------------------
# Step 8: Copy the built tarball to the original directory
# ----------------------------------------------------------------------------
echo "Step 8: Copying built tarball to working directory"
echo "------------------------------------------------------------"
cp "${EXPECTED_TARBALL}" "${FINAL_TARBALL}"
echo "  [OK] Final tarball: ${FINAL_TARBALL}"
echo ""

# ----------------------------------------------------------------------------
# Step 9: Run R CMD check --as-cran on the built tarball
# ----------------------------------------------------------------------------
echo "Step 9: Running R CMD check --as-cran"
echo "------------------------------------------------------------"
echo "  This may take 2-5 minutes."
echo ""
R CMD check --as-cran "${EXPECTED_TARBALL}" || true
echo ""

# ----------------------------------------------------------------------------
# Step 10: Final summary
# ----------------------------------------------------------------------------
echo "============================================================"
echo "  BUILD COMPLETE"
echo "============================================================"
echo ""
echo "  Official CRAN tarball:"
echo "    ${FINAL_TARBALL}"
echo ""
echo "  Size: $(ls -lh "${FINAL_TARBALL}" | awk '{print $5}')"
echo "  SHA-256: $(shasum -a 256 "${FINAL_TARBALL}" | awk '{print $1}')"
echo ""
echo "  This tarball was created by R CMD build and includes:"
echo "    - Built vignette in inst/doc/forestr-workflow.html"
echo "    - MD5 checksum file"
echo "    - All R source, tests, man/, vignettes/, DESCRIPTION, NAMESPACE"
echo ""
echo "  Next steps:"
echo "    1. Review the R CMD check output above."
echo "       It should show: 0 ERRORs, 0 WARNINGs, 1 NOTE ('New submission')."
echo "    2. (Recommended) Run on Windows via WinBuilder:"
echo "         Rscript -e 'devtools::check_win_devel()'"
echo "    3. (Recommended) Run on Linux/macOS via R-hub:"
echo "         Rscript -e 'rhub::check_for_cran()'"
echo "    4. Upload ${EXPECTED_TARBALL} to:"
echo "         https://CRAN.R-project.org/submit.html"
echo "       Maintainer: adamugi009@gmail.com"
echo "       Optional comment: paste the content of CRAN-comments.md"
echo ""
echo "============================================================"

# Clean up work directory (optional — comment out to keep for debugging)
cd "$(dirname "${FINAL_TARBALL}")"
rm -rf "${WORK_DIR}"

# shellcheck disable=all
# ATLAS configuration file
# Directory where create_project.sh stores generated project directories
PROJ_DIR=""
# Directory where activate_data.sh stores activated data
ACTIVE_DATA_DIR=""
# Directory where freeze_study.sh stores temporary frozen studies
FREEZE_DIR=""
# The directory where archive_study.sh stores archived studies
ARCHIVE_DIR=""
# The directory that the various README templates used in ATLAS are held
TEMPLATE_DIR=""
# The size of the study (in gb) above which the archive_study.sh script 
# will prompt the user to confirm before proceeding with archiving
ARCHIVE_SIZE_THRESHOLD_GB="value"

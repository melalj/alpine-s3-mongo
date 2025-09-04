#!/usr/bin/bash
set -e

required_vars="AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_DEFAULT_REGION S3_BUCKET"

for var in $required_vars; do
	if [ -z "$(eval echo \$$var)" ]; then
		echo "Error: Environment variable $var is not set."
		exit 1
	fi
done

# Default to BACKUP_ARCHIVE_NAME if LIST_ARCHIVE_NAME not specified
ARCHIVE_NAME=${LIST_ARCHIVE_NAME:-$BACKUP_ARCHIVE_NAME}

if [ -z "$ARCHIVE_NAME" ]; then
	echo "Error: Either LIST_ARCHIVE_NAME or BACKUP_ARCHIVE_NAME must be set."
	exit 1
fi

echo "Configuring AWS credentials"
export AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID
export AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY
export AWS_DEFAULT_REGION=$AWS_DEFAULT_REGION

echo "Listing all versions of $ARCHIVE_NAME in bucket $S3_BUCKET:"
echo ""

/usr/bin/aws s3api list-object-versions \
	--bucket $S3_BUCKET \
	--prefix $ARCHIVE_NAME \
	--query 'Versions[?Key==`'$ARCHIVE_NAME'`].[LastModified,VersionId,Size,IsLatest]' \
	--output table

echo ""
echo "To restore a specific version, set RESTORE_VERSION_ID to the desired VersionId and run restore.sh"

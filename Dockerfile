FROM mysql:8.0

ENV MYSQL_DATABASE=tcrd

# URL of the MySQL dump tarball to restore at first-boot initialization
ENV DUMP_URL=https://unmtid-dbs.net/download/TCRD/latest.sql.gz

# Install curl
RUN microdnf install -y curl && microdnf clean all

# Copy the restore + user-provisioning script into the init directory
COPY restore.sh /docker-entrypoint-initdb.d/restore.sh

# Ensure the restore script is executable
RUN chmod +x /docker-entrypoint-initdb.d/restore.sh

# Document default MySQL port
EXPOSE 3306


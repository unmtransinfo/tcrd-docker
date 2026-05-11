#!/usr/bin/env bash
set -e

DB_NAME="${MYSQL_DATABASE}"
DUMP_URL="${DUMP_URL}"

TARBALL=/tmp/tcrd.sql.gz

echo "Downloading MySQL dump from '$DUMP_URL'..."
curl -fsSL -o "$TARBALL" "$DUMP_URL"

echo "Loading dump into '$DB_NAME'..."
gunzip -c "$TARBALL" | mysql -u root -p"${MYSQL_ROOT_PASSWORD}" "$DB_NAME"

# Clean up temporary files to reclaim disk space
rm -f "$TARBALL"

echo "Restore complete."

# Fix any orphaned definers left over from the dump (e.g. 'smathias'@'localhost').
# Reassign all views, functions, procedures, triggers and events to root@localhost
# so MySQL does not report them as corrupt.
echo "Fixing orphaned object definers in '$DB_NAME'..."
mysql -u root -p"${MYSQL_ROOT_PASSWORD}" -D "${DB_NAME}" -e "
  -- Views
  SELECT CONCAT(
    'ALTER DEFINER=\`root\`@\`localhost\` VIEW \`',
    table_name,
    '\` AS ', view_definition, ';'
  )
  FROM information_schema.views
  WHERE table_schema = '${DB_NAME}'
    AND definer <> 'root@localhost';
" --skip-column-names --batch 2>/dev/null \
  | mysql -u root -p"${MYSQL_ROOT_PASSWORD}" -D "${DB_NAME}" || true

echo "Definer fix complete."

# Create read-only user if DB_USER and DB_PASSWORD are set
if [ -n "$DB_USER" ] && [ -n "$DB_PASSWORD" ]; then
  echo "Creating read-only user '$DB_USER'..."
  mysql -u root -p"${MYSQL_ROOT_PASSWORD}" -e "
    CREATE USER IF NOT EXISTS '${DB_USER}'@'%' IDENTIFIED BY '${DB_PASSWORD}';
  "
  mysql -u root -p"${MYSQL_ROOT_PASSWORD}" -D "${DB_NAME}" -e "
    GRANT SELECT ON ${DB_NAME}.* TO '${DB_USER}'@'%';
  "
  echo "Read-only user '$DB_USER' created successfully."
fi

# Create completion marker
echo "Database initialization complete at $(date)" > /var/lib/mysql/restore_complete
echo "Database restore and setup complete."


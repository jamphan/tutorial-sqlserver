#!/bin/bash
set -e
SA_PASSWORD=${SA_PASSWORD}

if [ "$1" = '/opt/mssql/bin/sqlservr' ]; then
  # If this is the container's first run, initialize the application database
  if [ ! -f /tmp/app-initialized ]; then
    # Initialize the application database asynchronously in a background process. This allows a) the SQL Server process to be the main process in the container, which allows graceful shutdown and other goodies, and b) us to only start the SQL Server process once, as opposed to starting, stopping, then starting it again.
    function initialize_app_database() {
      # Wait a bit for SQL Server to start. SQL Server's process doesn't provide a clever way to check if it's up or not, and it needs to be up before we can import the application database
      sleep 20s
      #run the setup script to create the DB and the schema in the DB
      /opt/mssql-tools/bin/sqlcmd -S localhost -U sa -P $SA_PASSWORD -d master -Q "CREATE LOGIN ${DB_USER} WITH PASSWORD = '${DB_PASSWORD}';"

      # TODO: sysadmin is only needed for Azure Data Studio, an active bug prevents the Object Explorer from loading for any login that does not have sysadmin access
      # see: https://github.com/microsoft/azuredatastudio/issues/13915
      /opt/mssql-tools/bin/sqlcmd -S localhost -U sa -P $SA_PASSWORD -d master -Q "ALTER SERVER ROLE sysadmin ADD MEMBER ${DB_USER};"
      /opt/mssql-tools/bin/sqlcmd -S localhost -U sa -P $SA_PASSWORD -d master -Q "CREATE DATABASE learnsql;"
      /opt/mssql-tools/bin/sqlcmd -S localhost -U sa -P $SA_PASSWORD -d master -Q "ALTER AUTHORIZATION ON DATABASE::learnsql TO ${DB_USER};"
      /opt/mssql-tools/bin/sqlcmd -S localhost -U sa -P $SA_PASSWORD -d master -i init.sql
      # Note that the container has been initialized so future starts won't wipe changes to the data
      touch /tmp/app-initialized
    }
    initialize_app_database &
  fi
fi
exec "$@"
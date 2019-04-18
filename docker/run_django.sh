#!/bin/sh

echo "Waiting for database connection..."

until netcat -z -v -w30 $DB_HOST $DB_PORT
do
  sleep 1
done

echo "WEB IS RUNNING"

# Static files
npm cache clean
npm install .
npm install -g less
npm run build-css
python manage.py collectstatic --noinput

# migrate db, so we have the latest db schema
python manage.py migrate

# If the above migrations are failing upgrade an older database like so:
#   # Unsure why I had to specially migrate this one
#   $ python manage.py migrate oauth2_provider --fake
#   $ python manage.py migrate --fake-initial

# Insert initial data into the database
python scripts/initialize.py

# start development server on public ip interface, on port 8000
PYTHONUNBUFFERED=TRUE gunicorn codalab.wsgi \
    --bind django:$DJANGO_PORT \
    --access-logfile=/var/log/django/access.log \
    --error-logfile=/var/log/django/error.log \
    --log-level $DJANGO_LOG_LEVEL \
    --reload \
    --timeout 4096 \
    --enable-stdio-inheritance \
    --workers=${GUNICORN_CONCURRENCY:-1}

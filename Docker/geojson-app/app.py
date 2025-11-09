import boto3
import os 
import geojson
import logging
import json
import sys
import psycopg2
from psycopg2.extras import Json

####Logging####
logger = logging.getLogger()
logger.setLevel(logging.INFO)
handler = logging.StreamHandler(sys.stdout)
formatter = logging.Formatter('%(asctime)s - %(levelname)s - %(message)s')
handler.setFormatter(formatter)
logger.addHandler(handler)

#####Configuration####
S3_BUCKET = os.getenv("S3_BUCKET")
S3_KEY      = os.getenv("S3_KEY")
DB_HOST     = os.getenv("DB_HOST")
DB_NAME     = os.getenv("DB_NAME", "postgres")
DB_USER     = os.getenv("DB_USER")
DB_PASS     = os.getenv("DB_PASS")
DB_PORT     = int(os.getenv("DB_PORT", "5432"))
TABLE_NAME  = os.getenv("TABLE_NAME", "geo_features")
GEOM_SRID   = int(os.getenv("GEOM_SRID", "4326"))

#####Environment Variable Validation####
required_env = ["S3_BUCKET", "S3_KEY", "DB_HOST", "DB_USER", "DB_PASS"]
missing = [e for e in required_env if not os.getenv(e)]
if missing:
    logger.error(f"Missing required environment variables: {', '.join(missing)}")
    sys.exit(1)

s3 = boto3.client('s3')

####Functions####

#####Ensuring GeoJSON is valid and reading from S3####
def read_geojson_from_s3(bucket: str, key: str) -> geojson.GeoJSON:
    logger.info(f"Reading GeoJSON from S3 Bucket: {bucket}, Key: {key}")
    obj = s3.get_object(Bucket=bucket, Key=key)
    content = obj['Body'].read().decode('utf-8')
    try:
        gj=geojson.loads(content)
        logger.info("✓ Successfully read GeoJSON from S3")
        return gj
    except Exception as e:
        logger.error(f"✗ Error reading GeoJSON from S3: {str(e)}")
        raise ValueError("Invalid GeoJSON content")


#####Ensuring GeoJSON is a FeatureCollection####
def validate_feature_collection(gj: geojson.GeoJSON) -> geojson.FeatureCollection:
    if not isinstance(gj, geojson.FeatureCollection):
        logger.error("✗ GeoJSON is not a FeatureCollection")
        raise ValueError("GeoJSON is not a FeatureCollection")
    if not isinstance(gj.features, list) or len(gj.features) == 0:
        raise ValueError("FeatureCollection has no features")
    return gj

#####Database Connection####
def db_connect():
    conn = psycopg2.connect(
        host=DB_HOST,
        database=DB_NAME,
        user=DB_USER,
        password=DB_PASS,
        port=DB_PORT
    )
    conn.autocommit = True
    return conn
####ensure Table Exists####
def ensure_table(conn):
    sql = f"""
    CREATE TABLE IF NOT EXISTS {TABLE_NAME} (
        id SERIAL PRIMARY KEY,
        name TEXT,
        properties JSONB,
        geom geometry(GEOMETRY, {GEOM_SRID})
    );
    """
    with conn.cursor() as cur:
        cur.execute(sql)
        logger.info(f"✓ Ensured table {TABLE_NAME} exists")

#####Insert Features into Database####
def insert_feature(conn, fc: geojson.FeatureCollection):
    sql = f"""
    INSERT INTO {TABLE_NAME} (name, properties, geom)
    VALUES (%s, %s, ST_SetSRID(ST_GeomFromGeoJSON(%s), %s));
    """
    inserted = 0
    with conn.cursor() as cur:
        for f in fc.features:
            geom_obj = f.get("geometry")
            if not geom_obj:
                logger.warning("Feature missing geometry, skipping")
                continue
            geom_json = json.dumps(geom_obj)

            props = f.get("properties") or {}
            name = props.get("name") or f.get("id") or None
            cur.execute(sql, (name, Json(props), geom_json, GEOM_SRID))
            inserted += 1
    logger.info(f"✓ Inserted {inserted} features into {TABLE_NAME}")
#####Main Handler####
def handler(event=None, context=None):
    try:
        gj = read_geojson_from_s3(S3_BUCKET, S3_KEY)
        fc = validate_feature_collection(gj)
        logger.info("✓ Valid GeoJSON FeatureCollection")
        conn = db_connect()
        ensure_table(conn)
        insert_feature(conn, fc)
        conn.close()
        logger.info("✓ Database operations completed successfully")

        logger.info("✓ Done!")
        return 0
    except Exception as e:
        logger.error(f"✗ Error: {str(e)}")
        return 1
    
if __name__ == "__main__":
    sys.exit(handler())












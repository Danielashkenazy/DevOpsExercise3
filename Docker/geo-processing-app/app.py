from flask import Flask, request, jsonify
from osgeo import gdal
import tempfile
import boto3
import os
import logging
import sys


app = Flask(__name__)


logger = logging.getLogger()
logger.setLevel(logging.INFO)


handler = logging.StreamHandler(sys.stdout)
formatter = logging.Formatter('[%(asctime)s] %(levelname)s: %(message)s')
handler.setFormatter(formatter)
logger.addHandler(handler)

@app.route('/process', methods=['POST'])
def process_file():
    data = request.get_json()
    logger.info(f"Incoming request: {data}")

    s3_path = data.get('s3_path')
    if not s3_path:
        logger.warning("Missing s3_path in request")
        return jsonify({"error": "Missing 's3_path'"}), 400

    if not s3_path.startswith("s3://"):
        logger.warning(f"Invalid S3 path: {s3_path}")
        return jsonify({"error": "Invalid S3 path"}), 400


    path_without_prefix = s3_path.replace("s3://", "", 1)

    path_parts = path_without_prefix.split('/', 1)

    bucket = path_parts[0]
    key = path_parts[1] if len(path_parts) > 1 else ""

    logger.info(f"Downloading file from S3: bucket={bucket}, key={key}")

    try:
        s3 = boto3.client('s3')
        tmp = tempfile.NamedTemporaryFile(delete=False)
        s3.download_file(bucket, key, tmp.name)
        logger.info("File downloaded successfully")
    except Exception as e:
        logger.exception("Failed to download from S3")
        return jsonify({"error": str(e)}), 500

    try:
        ds = gdal.Open(tmp.name)
        if not ds:
            raise Exception("GDAL failed to open the file")

        metadata = {
            "RasterXSize": ds.RasterXSize,
            "RasterYSize": ds.RasterYSize,
            "Projection": ds.GetProjection(),
            "GeoTransform": ds.GetGeoTransform(),
        }

        logger.info(f"Processed successfully: {metadata}")
        return jsonify(metadata), 200

    except Exception as e:
        logger.exception("Processing error")
        return jsonify({"error": str(e)}), 500

    finally:
        os.remove(tmp.name)
        logger.info("Temporary file removed")

@app.route('/health', methods=['GET'])
def health_check():
    return jsonify({"status": "healthy"}), 200


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8080)

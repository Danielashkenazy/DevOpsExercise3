FROM osgeo/gdal:ubuntu-full-3.6.3

WORKDIR /app

RUN apt-get update && apt-get install -y \
    python3 python3-pip python3-dev build-essential gdal-bin libgdal-dev \
    && rm -rf /var/lib/apt/lists/*

ENV CPLUS_INCLUDE_PATH=/usr/include/gdal
ENV C_INCLUDE_PATH=/usr/include/gdal

COPY Requirements.txt .
RUN pip3 install --upgrade pip && pip3 install --no-cache-dir -r Requirements.txt

COPY . .

EXPOSE 8080
CMD ["python3", "-u", "app.py"]

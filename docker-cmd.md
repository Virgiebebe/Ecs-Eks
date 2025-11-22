Instructions to Install and run Docker container

1. Make the script executable
``` chmod +x script.sh```

2. Run the installation script
```./script.sh```

3. Verify Docker is installed
```docker --version```

4. Build image with tag
```docker build -t flask-app .```

5. Run container
```docker run -d -p 3000:3000 flask-app```

6. Login to Docker from Vm to push image
docker login -u YOUR_DOCKERHUB_USERNAME



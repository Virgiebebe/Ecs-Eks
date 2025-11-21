1. After building the image Login to dockerhub
``` docker login -u YOUR_DOCKERHUB_USERNAME```

2. Tag your Docker image
```docker tag flask-app:latest YOUR_DOCKERHUB_USERNAME/flask-app:latest ```

3. Push the image to Docker Hub
``` docker push YOUR_DOCKERHUB_USERNAME/flask-app:latest```

ps : if using sudo, then use sudo to login lol
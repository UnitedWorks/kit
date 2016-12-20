#kit
----
##Docker Guide##
To get a image created and container running for the API, we're going to need two commands.

###Running a Docker Container
First, create your image. The `-t` flag lets you give the image an identifier. The `.` at the end states that the current directory is where to build from (and look for our Dockerfile). You can do this in either the kit_api or kit_dashboard directories.
```
  docker build -t kit_dashboard:latest .
```

Second, we run our image. The `-it` flags let you interact with the container via command line and setup stdin/stdout. Using the `-d` flag instead lets you run it detached. The `-p` flag takes exposed ports in the container (defined in the Dockerfile), and maps them to the host(127.0.0.1). Finally, we specify which image we want to create our container from.
```
  docker run -it -p 8000:8000 kit_dashboard:latest
```

###Running a Docker Network - Linked Containers
Running an API container without a connected database isn't too useful. To link up an isolated Postgres database, we need to utilize `docker-compose`.

To create this type of image, we're going to use commands that read off our `docker-compose.yml` file. Since our configuraiton sits there, all we need to do is:
```
  docker-compose build
```

To run this type container, we're going to use a docker-compose command which constructs a docker network.
```
  docker-compose up
```

###What you can do to docker containers
* `ps` - List containers/networks
* `start/stop/restart` - Manage containers (they persist information)
* `rm` - Remove containers
* `commit` - After making changes to a container, you can create a new image
* `pull` - Lets you pull a version down from DockerHub

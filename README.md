# titanic-julia

### Running Jupyter w/ Docker

#### Prerequisites

You'll need Docker installed from here: 

[https://www.docker.com/products/overview](https://www.docker.com/products/overview)

#### Building

From the project directory, run:

```
docker build -t cybera/julia .
```

#### Running Jupyter

From the project directory, run:

```
docker run -d -p 8888:8888 --entrypoint="/usr/local/bin/jupyter-notebook" \
-v "$PWD":/titanic-julia --name titanic-julia \
cybera/julia --ip=\* --notebook-dir=/titanic-julia
```

And go to [http://localhost:8888](http://localhost:8888) in your browser.

*Note: You don't have to give it a name (via `--name`). In this case, docker
will assign a random name that you'll have to use with any `docker stop` or 
`docker exec` commands.*

#### Command-line (for running container)

```
docker exec -it titanic-julia bash
```

#### Cleaning up

```
docker stop titanic-julia && docker rm titanic-julia
```
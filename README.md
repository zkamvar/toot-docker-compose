# Docker Compose toot

Date: 2020-03-25

## Motivation

I am trying to learn docker-compose because I *believe* that it *may* be able to
help us deploy a better system for building tutorials for the maintainers. The
current system works to a degree, but requires the maintainers to have similar
computational setups. This limits the nubmer of people who can contribute
lessons to those who are technically adept. We want to lower the barrier.

This toot is from <https://docs.docker.com/compose/gettingstarted/>. 

## My Notes

I was a bit confused as to what the need for this was, but now I think I get it.
This is effectivley a way to set up systems that share docker containers on a
server (if I'm correct). The python script counts visits to a webpage and stores
those counts in a ReDiS database. The thing is that you NEED redis installed in
order to use the database. That's where `docker-compose` comes in. Instead of
explictly stating that you need to add the redis layer on your container, you
can say "I need the redis image for this to work" and docker-compose will make
it available for your python app to work.

## How this applies to my situation

I think this is an imperfect hammer for the infrastructure. On the one hand, we
don't have to create a whole bunch of new containers for each lesson, but we
still have to deal with the weird inconsistencies with docker a la permissions
smashing.     
ᕕ( ᐛ )ᕗ 

This is what I *think* it should look like to build an R lesson that depends on
the tidyverse (which I don't think we have for stability):

 - Dockerfile
    ```Docker
    ARG JEKYLL_VERSION 3.8.5
    FROM jekyll/jekyll:${JEKYLL_VERSION}
    COPY . /srv/jekyll/
    RUN bundle install \
     && bundle update
    ```
 - docker-compose.yml
   ```yaml
   version: "3"
   services:
     site:
       build: .
       ports: 
         - "4000:4000"
       command: jekyll serve
    needs:
      image: rocker/verse:latest
      command: bin/knit-lessons.sh
    ```

### Quirks I'm finding:

I've attempted to write this in such a way that I will first ship a docker
container that is built on the jekyll container, with a new directory that
contains the gemfiles: `/srv/gems/`. The gems are built from there and the
container is ready to go. I've written a docker-compose yaml file that looks
like this in the r-novice-gapminder repo:

```yaml
version: "3"
services:
  site:
    image: znk-test
    ports:
      - "4000:4000"
    volumes:
      - .:/srv/jekyll/
    command: make serve
    depends_on:
      - needs
  needs:
    image: rocker/verse:latest
    command: date

```

 - I attempted to build the RMD files on the rocker, but the files are on the
   jekyll volume. 
 - If I tried to mount the files on the rocker volume as well, I get in trouble
   because it defaults to the root directory and you cant execute multiple
   commands there. 
 - When I try to run make serve, I'm confronted with docker saying that it
   cannot find Rscript, which means that it may not be sensing the other
   container... which makes a bit of sense because it's not clear where exactly
   it's to be found on the path. 

### Insight

I think a key piece of information I'm missing is the fact that this creates a
*network* of docker containers. If we look at the python script, we can see on
line 7:

```python
cache = redis.Redis(host='redis', port=6379)
```

That host parameter is saying "connect me to the network named 'host'." This was
something that was completely lost on me! I didn't realize that redis was 
supposed to be hosted on a server somewhere (why does my redis hurt? Because
you've never used it before.) and now it *kind of* makes sense. The question is:
how do I use this knowledge to execute commands on my.... oh my god! I forgot
about the fact that we can have makefiles move to a directory before executing!
Now I can link my directory to the first docker container and run make lesson-md
on it!

Of course, the problem here is that now it has to install everything :/

Perhaps the solution is to just use rocker/verse and be done with it. That way,
we are fairly certain to not have to download the whole of CRAN just to run 
the image. 

Okay, so I'm now having problems with linking my folders to the image :/

Okay... I fixed things to a degree. This is what my current setup looks like
(yes, it is ugly, but I don't particularly care at this point because I can
always clean it up):


```yaml
version: "3"
services:
  site:
    build: ../Git/tests/zkamvar--carpentries-docker-test
    ports:
      - "4000:4000"
    volumes:
      - .:/srv/jekyll/
    command: /bin/bash -c "cp ../gems/* . && jekyll serve"
    depends_on:
      - needs
  needs:
    image: rocker/verse:latest
    volumes:
      - .:/home/docker
    command: make -C /home/docker lesson-md

```

My Dockerfile in the zkamvar--carpentries-docker-test looks like this:

```Docker
# Explicitly set Jekyll version across all repos
ARG JEKYLL_VERSION=3.8.5
FROM jekyll/jekyll:${JEKYLL_VERSION}
COPY ./Gemfile /srv/gems/Gemfile

WORKDIR /srv

RUN chown jekyll:jekyll gems \
  && cd gems \
  && bundle update \
  && bundle install

WORKDIR /srv/jekyll
CMD bash
```


Now... one of the problems I'm having with this setup is the fact that
everything is built up front, but never updated 😩.

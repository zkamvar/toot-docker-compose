# Docker Compose toot

Date: 2020-03-25

## Motivation

I am trying to learn docker-compose because I *believe* that it *may* be able to
help us deploy a better system for building tutorials for the maintainers. The
current system works to a degree, but requires the maintainers to have similar
computational setups. This limits the nubmer of people who can contribute
lessons to those who are technically adept. We want to lower the barrier.

This toot is from <https://docs.docker.com/compose/gettingstarted/>. 

# My notes

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

## Results

To recap where we were with the lessons, the user needs the following on thier
machine in order to properly build the lessons:

 - Internet connection
 - lesson template
 - git (installation pain: low to moderate)
 - GNU Make (installation pain: high for windows)
 - Python 3.4 (installation pain: moderate to high)
 - Ruby + Jekyll (installation pain: moderate to high)

While no one needs to know how the latter three work, it is expected that folks
understand how to use Git and Github to work with the lesson template and 
generate a lesson. 

Remember, we want users to be able to contribute lessons by just writing
markdown and not having to worry about any details that are more technical than
their lessons. 

The path that I thought about having was to use [docker-compose](https://docs.docker.com/compose/install/) to build everything. This way, the user only needs the following:

 - Internet connection
 - [Docker](https://docs.docker.com/install/#desktop)
 - lesson template
 - git (N.B. this is *optional* with this setup)

This is the current setup in the <https://github.com/swcarpentry/r-novice-gapminder/tree/2020-03-26-znk> repository:

 - Docker container: <https://hub.docker.com/u/zkamvar/carpentries-docker-test>
 - Make command: 
    ```make
    serve-in-container : lesson-md
      cp ../gems/* . \
      && ${JEKYLL} serve -d /srv/jekyll/
    ```
 - docker-compose.yml:
    ```yaml
    version: "3"
    services:
      site:
        image: zkamvar/carpentries-docker-test:latest
        ports:
          - "4000:4000"
        volumes:
          - .:/srv/src/
        command: make -C ../src serve-in-container
        depends_on:
          - needs
      needs:
        image: rocker/verse:latest
        volumes:
          - .:/home/docker
        command: make -C /home/docker lesson-md
    ```


We can run the following command to see how this works:

```bash
curl -L https://api.github.com/repos/swcarpentry/r-novice-gapminder/tarball/914b882 | tar -xvz \
&& cd swcarpentry-r-novice-gapminder-914b882 \
&& docker-compose up
```


Below are my notes as I went through this

--------------------------------------------------------------------------------

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

### IT WORKS 😹 (kinda 👀)

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
everything is built up front, but never updated 😩. It's a bit weird because if
I were to change one of the RMarkdown files in the `_episodes_rmd/` folders and
re-run the container, the `needs` container (I should really rename it to
describe what it actually is: a computer with R on it) will rebuild the
Rmarkdown and jekyll will re-serve it, but it would never update despite the
fact that things are clearly being written on my machine from the `needs`, but
somehow never properly updated on the `site` container :/

I think this will be another exercise for tomorrow!


### Day 2/3 (I'm not sure anymore)

I have destroyed all of the containers and now I'm back to the same familiar
error:

```
07:54:57 ~/Documents/Carpentries/swcarpentry--r-novice-gapminder
(2020-03-26-znk)$ docker-compose up
Starting swcarpentryrnovicegapminder_needs_1 ... 
Starting swcarpentryrnovicegapminder_needs_1 ... done
Starting swcarpentryrnovicegapminder_site_1 ... 
Starting swcarpentryrnovicegapminder_site_1 ... done
Attaching to swcarpentryrnovicegapminder_needs_1, swcarpentryrnovicegapminder_site_1
needs_1  | make: Entering directory '/home/docker'
needs_1  | make: Nothing to be done for 'lesson-md'.
needs_1  | make: Leaving directory '/home/docker'
swcarpentryrnovicegapminder_needs_1 exited with code 0
site_1   | ruby 2.6.3p62 (2019-04-16 revision 67580) [x86_64-linux-musl]
site_1   | Configuration file: /srv/jekyll/_config.yml
site_1   |             Source: /srv/jekyll
site_1   |        Destination: /srv/jekyll/_site
site_1   |  Incremental build: disabled. Enable with --incremental
site_1   |       Generating... 
site_1   | jekyll 3.8.5 | Error:  Permission denied @ dir_s_mkdir - /srv/jekyll/_site
swcarpentryrnovicegapminder_site_1 exited with code 1
```

How fun! Permission issues are going to be a bit of a running theme, I think. 

I'm once again questioning: is this the right hammer I need for the job? The
problem with rolling a specific dockerfile for each instance is that, well, it
falls on the maintainer to do that and it's just one more or one new piece of 
technology that they have to get to know. 

But in the meantime, I've added the dockerfile to the docker registry:

<https://github.com/zkamvar/carpentries-docker-test>

> Three hours later...

Okay, so the problem was that I had not included `_site/` in my directory
structure, so it was having problems working. Note: I am currently still
working in <https://github.com/swcarpentry/r-novice-gapminder> in my own custom
branch.

I've removed all of the docker containers AND images that I had and cleaned up
my git session:

```bash
docker rm $(docker ps -a -q)        # remove all containers
docker rmi $(docker image ls -a -q) # remove all downloaded images
git checkout -- . # reset all tracked files to their original states
git clean -fd     # remove all untracked files
```

#### Running the container from scratch

I've gotten things to work... sort of. Here is my current setup:

 - Docker container: <https://hub.docker.com/u/zkamvar/carpentries-docker-test>
 - Make command: 
    ```make
    serve-in-container : lesson-md
      cp ../gems/* . \
      && ${JEKYLL} serve -d /srv/jekyll/
    ```

 - docker-compose.yml:
    ```yaml
    version: "3"
    services:
      site:
        image: zkamvar/carpentries-docker-test:latest
        ports:
          - "4000:4000"
        volumes:
          - .:/srv/src/
        command: make -C ../src serve-in-container
        depends_on:
          - needs
      needs:
        image: rocker/verse:latest
        volumes:
          - .:/home/docker
        command: make -C /home/docker lesson-md
    ```

Here's what happens when I run the commands:

```sh
(2020-03-26-znk)$ docker-compose up
Pulling needs (rocker/verse:latest)...
latest: Pulling from rocker/verse
8f0fdd3eaac0: Pull complete
c42f03650681: Pull complete
e8d8a2a587cb: Pull complete
8070157c9f99: Pull complete
0a7a0529ec26: Pull complete
8781e7725be3: Pull complete
dfd244768473: Pull complete
0346eddd3dca: Pull complete
444d6a84b975: Pull complete
Digest: sha256:ce9e3c004bb2b0d6b5ca6235645b57d540d6012b7e3f5635d0c632c0ebae85af
Status: Downloaded newer image for rocker/verse:latest
Pulling site (zkamvar/carpentries-docker-test:latest)...
latest: Pulling from zkamvar/carpentries-docker-test
050382585609: Pull complete
cb9e14f894ff: Pull complete
78b911433595: Pull complete
abf8325464c1: Pull complete
2549eba3f0d0: Pull complete
44d38c40f9af: Pull complete
83a7755db110: Pull complete
e26c08fe8e4d: Pull complete
Digest: sha256:2716c4fab334d7f89da2ba0e175033f2706208d2b84d3ce05972d8faf58f116a
Status: Downloaded newer image for zkamvar/carpentries-docker-test:latest
Creating swcarpentryrnovicegapminder_needs_1 ... 
Creating swcarpentryrnovicegapminder_needs_1 ... done
Creating swcarpentryrnovicegapminder_site_1 ... 
Creating swcarpentryrnovicegapminder_site_1 ... done
Attaching to swcarpentryrnovicegapminder_needs_1, swcarpentryrnovicegapminder_site_1
needs_1  | make: Entering directory '/home/docker'
needs_1  | make: Nothing to be done for 'lesson-md'.
needs_1  | make: Leaving directory '/home/docker'
site_1   | make: Entering directory '/srv/src'
site_1   | cp ../gems/* . \
site_1   | && jekyll serve -d /srv/jekyll/
swcarpentryrnovicegapminder_needs_1 exited with code 0
site_1   | ruby 2.6.3p62 (2019-04-16 revision 67580) [x86_64-linux-musl]
site_1   | Configuration file: /srv/src/_config.yml
site_1   |             Source: /srv/src
site_1   |        Destination: /srv/jekyll/
site_1   |  Incremental build: disabled. Enable with --incremental
site_1   |       Generating... 
site_1   |                     done in 1.796 seconds.
site_1   |  Auto-regeneration: enabled for '/srv/src'
site_1   |     Server address: http://0.0.0.0:4000
site_1   |   Server running... press ctrl-c to stop.
```

When I look at my files now, I have two untracked files that belong to root

> This may not be the best idea since a user without priviledges cannot remove
> these files. 

```
-rw-r--r--  1 root  root  6.8K Mar 27 10:41 Gemfile.lock
-rw-r--r--  1 root  root   244 Mar 27 10:41 Gemfile
drwxrwxr-x 18 zhian zhian 4.0K Mar 27 10:41 .
```

#### Modifying a file

Let's say I modify one of the source RMD files. What happens then? For example,
I'll change line 78 of the dplyr example:

```diff
-year_country_gdp <- select(gapminder,year,country,gdpPercap)
+year_country_gdp <- select(gapminder, year, country, gdpPercap)
```

When I run `docker-compose up` now, I get:

```
(2020-03-26-znk)$ docker-compose up
Starting swcarpentryrnovicegapminder_needs_1 ... 
Starting swcarpentryrnovicegapminder_needs_1 ... done
Starting swcarpentryrnovicegapminder_site_1 ... 
Starting swcarpentryrnovicegapminder_site_1 ... done
Attaching to swcarpentryrnovicegapminder_needs_1, swcarpentryrnovicegapminder_site_1
needs_1  | make: Entering directory '/home/docker'
site_1   | make: Entering directory '/srv/src'
site_1   | bin/knit_lessons.sh: line 7: Rscript: command not found
site_1   | make: Leaving directory '/srv/src'
site_1   | make: *** [Makefile:96: _episodes/13-dplyr.md] Error 127
needs_1  | Downloading GitHub repo hadley/requirements@master
swcarpentryrnovicegapminder_site_1 exited with code 2
needs_1  | rlang (0.4.4 -> 0.4.5) [CRAN]
needs_1  | Installing 1 packages: rlang
needs_1  | Installing package into ‘/usr/local/lib/R/site-library’
needs_1  | (as ‘lib’ is unspecified)
needs_1  | trying URL 'https://cran.rstudio.com/src/contrib/rlang_0.4.5.tar.gz'
needs_1  | Content type 'application/x-gzip' length 816813 bytes (797 KB)
needs_1  | ==================================================
needs_1  | downloaded 797 KB
needs_1  | 

[ snip ]

needs_1  | * DONE (rlang)
needs_1  | 
needs_1  | The downloaded source packages are in
needs_1  | 	‘/tmp/Rtmp9UeQLV/downloaded_packages’
✔  checking for file ‘/tmp/Rtmp9UeQLV/remotes73aa0d894/hadley-requirements-79ed4cc/DESCRIPTION’ ...
─  preparing ‘requirements’:

[ snip ]

needs_1  | * DONE (requirements)
needs_1  | Loading required package: knitr
needs_1  | 
needs_1  | 
needs_1  | processing file: _episodes_rmd/13-dplyr.Rmd

[ snip ]

needs_1  | output file: _episodes/13-dplyr.md
needs_1  | 
needs_1  | Warning message:
needs_1  | In library(package, lib.loc = lib.loc, character.only = TRUE, logical.return = TRUE,  :
needs_1  |   there is no package called ‘requirements’
needs_1  | make: Leaving directory '/home/docker'
swcarpentryrnovicegapminder_needs_1 exited with code 0
```

It's clear that both containers started up and successfully ran their processes,
but the site container did not wait for the R container to finish before it
attempted to start. How rude!

Of course, if we run `docker-compose up` again, it will be merciful:

```
(2020-03-26-znk)$ docker-compose up
Starting swcarpentryrnovicegapminder_needs_1 ... 
Starting swcarpentryrnovicegapminder_needs_1 ... done
Starting swcarpentryrnovicegapminder_site_1 ... 
Starting swcarpentryrnovicegapminder_site_1 ... done
Attaching to swcarpentryrnovicegapminder_needs_1, swcarpentryrnovicegapminder_site_1
needs_1  | make: Entering directory '/home/docker'
needs_1  | make: Nothing to be done for 'lesson-md'.
needs_1  | make: Leaving directory '/home/docker'
site_1   | make: Entering directory '/srv/src'
site_1   | cp ../gems/* . \
site_1   | && jekyll serve -d /srv/jekyll/
swcarpentryrnovicegapminder_needs_1 exited with code 0
site_1   | ruby 2.6.3p62 (2019-04-16 revision 67580) [x86_64-linux-musl]
site_1   | Configuration file: /srv/src/_config.yml
site_1   |             Source: /srv/src
site_1   |        Destination: /srv/jekyll/
site_1   |  Incremental build: disabled. Enable with --incremental
site_1   |       Generating... 
site_1   |                     done in 1.921 seconds.
site_1   |  Auto-regeneration: enabled for '/srv/src'
site_1   |     Server address: http://0.0.0.0:4000
site_1   |   Server running... press ctrl-c to stop.
```

Now we just have to see how well this works on my mac.

### On macOS

Well apparently, docker doesn't automatically update a container that's tagged
latest because I had one from 2018 (before we knew how bad things would get in
the world and our R scripts from 2011 were still reproducible). When I ran the 
updated script, it installed rlang (as it normally does), but then threw a lot
of errors because the version of dplyr in the container was incorrect.

When I ran `docker pull rocker/verse:latest`, it worked.



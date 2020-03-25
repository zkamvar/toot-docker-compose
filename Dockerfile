FROM python:3.7-alpine                            # start with python 3.7 alpine
WORKDIR /code                                     # set the wd to /code
ENV FLASK_APP app.py                              # set FLASK_APP (used by flask)
ENV FLASK_RUN_HOST 0.0.0.0                        # (used by flask)
RUN apk add --no-cache gcc musl-dev linux-headers # install gcc (apk is like apt)
COPY requirements.txt requirements.txt            # copy over requirements.txt
RUN pip install -r requirements.txt               # install packages needed
COPY . .                                          # copy the entire directory
CMD ["flask", "run"]                              # $ flask run

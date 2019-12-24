## Introduction

Cargo is a small Rails app that does two things:

- parse resumes: it sends a request to Sovren to parse resumes and returns the data from Sovren Convert documents to PDF: it takes a .doc, .docx file and
- converts it into a PDF and a HTML file which can be embedded into a webpage.

This needs to be a separate application because Heroku (our main host) has an ephemeral file system and as such, we cannot do any file processing there.  Cargo is hosted on DigitalOcean and deployed using Capistrano.


## Deployment

Check out the master branch and run `cap production deploy`.


## Local testing with Jets

https://rubyonjets.com/

Usage of Jets will allow us to convert this to a Lambda / API Gateway application.

WIP: To test locally first install with

`bundle install`

Set a temp development api key for auth testing:

`export AUTH_TOKEN=sometoken`

Then fire up the local server (If you have valid AWS Creds it will launch in your account as lambda/apigateway):

`jets server`

You can then hit the various routes:

`curl -F "file=@/some/file.doc" -F "is_resume=1" http://localhost:8888/uploader`

When attempting to hit a route that requires auth please add:
`-H "Authorization: Bearer sometoken"` to the curl command.
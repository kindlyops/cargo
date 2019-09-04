## Introduction

Cargo is a small Rails app that does two things:

- parse resumes: it sends a request to Sovren to parse resumes and returns the data from Sovren Convert documents to PDF: it takes a .doc, .docx file and
- converts it into a PDF and a HTML file which can be embedded into a webpage.

This needs to be a separate application because Heroku (our main host) has an ephemeral file system and as such, we cannot do any file processing there.  Cargo is hosted on DigitalOcean and deployed using Capistrano.


## Deployment

Check out the master branch and run `cap production deploy`.

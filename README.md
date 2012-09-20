Open Active Democracy has now been changed to Social Innovation - see https://github.com/rbjarnason/social_innovation It's the same codebase but has been cleaned up and a new simpler UI added.

Open Active Democracy is a web based platform that enables groups of people to define their democratic priorities and together discover which are the most important ideas to implement by their governments.  People can add new ideas, add arguments for and against priorities, indicate if they support or oppose an idea, create a personal list of priorities and discuss all priorities. The end results are lists of top priorities in many categories as well as the best arguments for and against each priority. This service enables people to make up their minds about most issues in a short time.

Open Active Democracy (Opna lýðræðiskerfið) is a merge between:

NationBuilder by Jim Gilliam
"http://www.jimgilliam.com/":http://www.jimgilliam.com/

* Jim's Nationbuilder has itself evolved into an excellent political campaign website
"http://www.nationbuilder.com/":http://www.nationbuilder.com/

and

Open Direct Democracy by Róbert Viðar Bjarnason and Gunnar Grimsson
"http://github.com/rbjarnason/open-direct-democracy":http://github.com/rbjarnason/open-direct-democracy

Installation
============

Ruby
----

First you'll want to install your own Ruby (if you haven't already). There are
a few ways to do that. The rest of this guide assumes you use bash and RVM.

First you install RVM (Ruby Version Manager):

````bash
$ bash -s stable < <(curl -s https://raw.github.com/wayneeseguin/rvm/master/binscripts/rvm-installer)
````

Then reload your environment:

````bash
$ source ~/.bash_profile
````

Find out what dependencies are needed for Ruby (MRI) and install them:

````bash
$ rvm requirements
````

Install and use Ruby 1.9.3

````bash
$ rvm install 1.9.3
$ rvm use 1.9.3 --default
````

Install Bundler

````bash
$ gem install bundler
````

Set up open-active-democracy
----------------------------

````bash
$ git clone https://github.com/rbjarnason/open-active-democracy.git
$ cd open-active-democracy
````

Install all the dependencies

````bash
$ bundle install
````

Modify database.yml and fill in your MySQL database credentials

````bash
$ $EDITOR config/database.yml
````

Then create and seed the database

````bash
$ rake db:create
$ rake db:schema:load
$ rake tr8n:init
$ rake tr8n:import_and_setup_iso_3166
$ rake db:seed
````

Run open-active-democracy
-------------------------

Finally, start the rails server:

````bash
$ rails server
````

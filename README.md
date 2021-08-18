# Braven Platform

[![Codacy Health Badge](https://api.codacy.com/project/badge/Grade/f800f0c485164dacb4b493d8acfb19e6)](https://www.codacy.com/manual/bebraven/platform)
[![Codacy Coverage Badge](https://api.codacy.com/project/badge/Coverage/f800f0c485164dacb4b493d8acfb19e6)](https://www.codacy.com/manual/bebraven/platform)

This is the Braven Platform!

Add to this README please. It's easy to edit and see your changes locally using [grip](https://github.com/joeyespo/grip).

## Initial setup

First, we need to copy a couple of environment files in the app directory:

    cp .env.example .env
    cp .env.database.example .env.database

Then you'll need to add your AWS credentials and the file upload bucket to your shell enviromnment (e.g. in `~/.bash_profile`):

    export AWS_ACCESS_KEY_ID=<your_key>
    export AWS_SECRET_ACCESS_KEY=<your_secret>
    export AWS_PLATFORM_FILES_BUCKET=<the_dev_file_uploads_bucket>

*Tip: make sure you `source` the file or restart your shell*

You don't really need to change the database passwords in these files, so we're doing this mainly to conform to "best
practices" for Rails apps in general. But if you do want to pick a different database password, make sure it matches in
both files.

Now fire up and build the docker environment. This will create/launch the Rails app, as well as a PostgreSQL database
server for the app to use:

    docker-compose up -d

This will take a while the first time, because Docker has to download a Ruby image and a PostgreSQL image and set them
up. It will also install all the necessary Ruby gems and JavaScript libraries the app requires.

Now create the needed databases:

    docker-compose run platformweb bundle run rake db:create db:schema:load db:dummies

We've configured Docker to run our Rails app on port 3020, so go to http://localhost:3020 in your favorite browser. If
everything's working correctly, you should be brought to the app's homepage.

Add a `127.0.0.1   platformweb` to your `/etc/hosts` file to access the Platform app via http://platformweb:3020.

### SSL support
We have an [nginx-dev
container](https://github.com/beyond-z/nginx-dev) that will allow you to access the app over SSL and without specifying the port number.

### Salesforce

If you need to work on anything that hits the Salesforce API, you'll need to setup the following
environment variables in your `~/.bash_profile`.
[Here is an article](https://developer.salesforce.com/docs/atlas.en-us.api_rest.meta/api_rest/quickstart_oauth.htm) to help you through the below steps.


    export SALESFORCE_PLATFORM_CONSUMER_KEY=<the_key>
    export SALESFORCE_PLATFORM_CONSUMER_SECRET=<the_secret>
    export SALESFORCE_PLATFORM_USERNAME=<the_username>
    export SALESFORCE_PLATFORM_PASSWORD=<the_password>
    export SALESFORCE_PLATFORM_SECURITY_TOKEN=<the_security_token>

The values to use come from the Connected App in the Salesforce environment you are working against and
for the user that setup that connected app. To create them in a given Salesforce environment (prod, staging, dev)
first ask someone to create a Salesforce account for you (or get the admin account).

1. Login and go to Setup (the little gear in the top right)
2. In the Quick Find type "App Manager".
3. Under App Manager, you can create a "New Connected App" in the top right.
4. Enable OAuth settings, put in anything for the callback URL (since we don't currently use it), and give it Full Access scope.

*Tip*: If you want to get the key/secret for an existing app click on the little dropdown arrow to the right of it and choose "View".

**Important Note**: whenever you change the password for the account that created the connected app, a new security token
will be emailed to that user in an email titled "Your new Salesforce security token".

### Canvas

#### Create a course
Create a course in Canvas as your sandbox/development environment. Call it `Playground - <insert your name>`. Publish it.

#### Create test users
In your Canvas course, select **People** in navigation and add test users to your course by email.

Your test user's email address will be your Braven email with a suffix identifying the user.

For example:

 - `myname+teststudent1@bebraven.org` for a student
 - `myname+testta1@bebraven.org` for a TA

After adding your test users, they need to accept their course invitations. There are a couple of ways to do this:

 - Email: check your email, click on the link to accept the invitation.
 - Canvas: go to **People**, select the user, then click **Act as User**. You will either automatically enroll, or be prompted by Canvas to join the course.

You also need to add your test user to your development database with the same email and Canvas ID.

To locate a user's Canvas ID, go to **People**, and hover over the user's name. The ID will appear in the URL.
For example: `https://braven.instructure.com/courses/48/users/78`. The user's Canvas ID is 78.

In you development directory, run `devc`, and add your test user in the Rails console.

Edit the **email** and **canvas_id** in the following to match those of your test user:

```
User.create email: 'some_email', canvas_id: canvas_id, admin: false, first_name: 'Test', last_name: 'Student', password: 'some_password', confirmed_at: DateTime.now
```

#### Configure Canvas API access token
We use the [Canvas API](https://canvas.instructure.com/doc/api/) to update Canvas Cloud, e.g. add assignments, sections, etc. This is implemented in our `CanvasAPI` library. In order to use this, you need to configure that following in your `.env` file:

```
CANVAS_URL=https://braven.instructure.com
CANVAS_TOKEN=<your user-generated access token>
```

To generate a Canvas access token, go to your [Canvas Account Settings](https://braven.instructure.com/profile/settings). In **Approved Integrations**, click **+ New Access Token**, fill out the form, then **Generate Token**.

Copy the token shown in the follow-up dialog and paste it into `CANVAS_TOKEN` in your `.env` file. You can always re-generate the token and update the environment variable if you lose it.

Restart your `platformweb` Docker container to pick up these changes.

At this point, you should be able to make modifications to your Canvas course using the `CanvasAPI`.

#### Configure and Deploy Your Personal LTI Extension
We add functionality to our [online Portal](https://braven.instructure.com) (aka Canvas) by implementing an LTI Extension. Details of what an LTI Extension is can be [found here](https://docs.google.com/document/d/1sLFnqo8-lr556EwyIUHy_jLWOwzGEkub6nFKDWPO58Y/edit?usp=sharing). In order to work on things are added to the Portal through LTI, you'll need to do the following:

[Configure and deploy an LTI extension](https://docs.google.com/document/d/1sLFnqo8-lr556EwyIUHy_jLWOwzGEkub6nFKDWPO58Y/edit#heading=h.pce3b8uoohrj) that will only work on your computer and hit your local development environment as follows (screenshots in the link):
1. Navigate to [Admin -> Developer Keys](https://braven.instructure.com/accounts/1/developer_keys) in the Portal.
1. Click `+ Developer Key -> + LTI Key`
1. Open one of the other developer's keys in a new tab and copy all the setting's from theirs, except adjust the names to your own and in the `Public JWK URL` field, enter your own ngrok URL. E.g. `https://<insertyourname>platform.ngrok.io/public_jwk`
1. Grab the Client ID, e.g. `160050000000000012`
1. Deploy the LTI extension only to your Playground course by navigating to `Playground Course -> Settings -> Apps -> View App Configurations` OR just use the URL: `https://braven.instructure.com/courses/[YOUR_COURSE_ID]/settings/configurations
1. Click `+ App`, change the `Configuration Type` dropdown to `By Client Id`, enter yours and submit.


#### Make Sure Your Dev Env Is Setup For SSL Support
Make sure you setup the nginx-dev container for [SSL Support](https://github.com/beyond-z/nginx-dev#ssl-support) and that https://platformweb works.

#### Make Your Dev Env Accessible From The Internet
Setup [ngrok.io](https://dashboard.ngrok.com/) in order to expose your local dev env to the public internet as follows:
1. Ask the team for an invite to [ngrok.io](https://dashboard.ngrok.com/). Create your account, download the tool, and configure it.
1. Reserve an ngrok subdomain [here](https://dashboard.ngrok.com/endpoints/domains) - call it `<insertyourname>platform` (e.g. `brianplatform`)
1. Start an ngrok tunnel with the command: `ngrok http https://platformweb -subdomain=<insertyourname>platform`
1. Check that you can hit your local dev env from the public internet at: `https://<insertyourname>platform.ngrok.io`

#### Does It Work?
At this point, you should be able to use the [Course Management page](`https://platformweb/courses`) to add update your Canvas course.

1. **Add Course Template** to add your Canvas course, using its ID (the ID can be found in the URL when you go to your Playground course, e.g. `https://braven.instructure.com/courses/43`). **For now, you need to do this manually in your Rails console**.
1. Find your course in the list [here](`https://platformweb/courses`) and **Edit**.
1. You should be able to **Add** Waivers, Peer Reviews, Modules, Projects, and Impact Surveys in the UI.
1. Click the link on the content's title and you should see it in Canvas as an Assignment.


### Dummy Data

In dev or staging environments, we may want a few users, etc to work with. Unlike the seed data above,
this data is NOT meant for production. Therefore, it has a separate source file (db/dummies.rb) and rake task:

    rake db:dummies

This currently generates a number of users. It uses our the factories from our test suite,
which have been updated to show more variety in names and emails.

## Making changes

The app should automatically pick up any changes you make and live-reload in your browser. If for some reason you need
to rebuild the container (e.g. you added a `gem` dependency), you can do so in two ways - with or without the docker
cache.

**Note**: When adding a new gem to the `Gemfile`, always run the `rebuild.sh` script below!

With cache (recommended):

    ./docker-compose/scripts/rebuild.sh

Without cache (slow! usually not necessary):

    docker-compose build --force-rm --no-cache
    docker-compose up -d

In rare cases, you may need to bypass docker-compose and use docker directly to remove all volumes:

    docker-compose down -v --rmi all --remove-orphans  # deletes all container data!
    docker volume rm platform_db-platform

If you change JavaScript dependencies, you need to restart the container, so yarn runs:

    docker-compose down
    docker-compose up -d

**Note:** there is a bug where on a Mac if you edit a file on the host machine (as opposed to inside the container)
then live reloading doesn't work. To fix this for vim, add the following to your .vimrc to make it work:

    set backupcopy=yes

See [this](https://github.com/guard/listen/issues/434) for more info and a link talking about other editors and
how they interact with gaurd.

### Testing

You can run all tests like this:

    docker-compose exec platformweb bundle exec rspec

Or only tests in a particular directory, like our feature tests which use Selenium to click around in the browser:

    docker-compose exec platformweb bundle exec rspec spec/feature

You can also run a single spec ofc.

JavaScript unit tests (using Jest) may not work inside your container. You can run them outside the container by first
installing the JS dependencies locally with `yarn`, then running Jest with:

    yarn test

### CI/CD Pipeline + Monitoring
TODO: write an overview of how we deploy, how we've configured CI, Booster vs Braven (vs soon to be Highlander) pipelines
      how Heroku has metrics and logs you can view, etc.

#### Continuous Integration

The platform pipeline in Heroku runs [continuous integration (CI) tests](https://dashboard.heroku.com/pipelines/0017371f-020c-434b-b666-c5b9870468ea/tests/1763) using the configuration in [app.json](https://devcenter.heroku.com/articles/heroku-ci#configuring-your-test-environment).

Most specs should run as part of the CI suite, so merging is blocked until tests pass.

However, if you have a flaky test (e.g., one that communicates with external services outside of VCR), you can [tag](https://relishapp.com/rspec/rspec-core/v/2-4/docs/command-line/tag-option) it with `ci_exclude`:

  it "flaky test", ci_exclude: true do; end

and it won't run as part of continuous integration.

#### Sentry
TODO: talk about this

#### Honeycomb
We've instrumented our server-side and client-side code to send traces and spans to [Honeycomb](https://ui.honeycomb.io/braven/datasets)
so we can troubleshoot and analyze it. While the auto-instrumentation is very useful, when writing new code you should
always ask yourself *"Is there information here that may be useful if problems arise and I need to troubleshoot?"* and
*"Am I worried this may have a performance impact?"* If the answer is yes to either, you should add some manual Honeycomb
instrumentation to your code.

[See here for more details about our Honeycomb setup](https://github.com/bebraven/platform/wiki/Honeycomb)

##### Server-side instrumentation
On the server-side we use [Honeycomb Beeline](https://docs.honeycomb.io/getting-data-in/ruby/beeline/). Here
is an example of how to add a piece of interesting information to the current trace:
```
Honeycomb.add_field('interesting_thing', 'banana')
```

And here is an example of wrapping something that may be slow in a span so you can find out for sure once
it comes under load in production:
```
Honeycomb.start_span(name: 'maybe_slow_operation') do |span|
  span.add_field('interesting_thing', 'banana')
end
```

##### Client-side instrumentation
On the client-side, use the wrapper classes in `honeycomb.js` to add manual instrumentation. E.g.
```
const honey_span = new HoneycombXhrSpan('controller.name', 'action.name', {
    'field1.to.add': 'value1',
    'field2.to.add': 'value2'});
```
To get an overall view of the user experience on a page including the Javascript that runs, group by
`trace.trace_id` in Honeycomb and click on the trace you want to see.

#### Codacy - Static Code Analysis (aka linter)
We use Codacy to run static code analysis. Everytime you push a branch to the repo it runs.

**You can see [status here](https://app.codacy.com/manual/bebraven/platform/dashboard)**

Make sure you get invited to the project so that you'll get emails about your code quality when you push.

*Note: you can also run it locally using the `codacy-analysis-cli` but I HIGHLY recommend against it. It's really hard
to get it working properly and the branch has to be completely clean and fully committed. Just push your branch and open a
pull request. Go fix any issues as well as get a peer code review before merging the pull request.*


### Project structure

This app is built with React and Rails. Generally speaking, developers will spend the most time in the Rails code
(models, views, controllers, and libs/helpers) and React components; designers will spend the most time in the React
components (HTML/JS/JSX) and CSS.

Rails views (ERB; these load the React components and handle backend API pages):

    app/views/layouts/application.html.erb
    app/views/*.erb

Rails models (database):

    app/models/*.rb

Rails controllers (business logic):

    app/controllers/*.rb

Rails [concerns](https://www.sitepoint.com/dry-off-your-rails-code-with-activesupportconcerns/)
(mixins for models and controllers, respectively):

    app/models/concerns/*.rb
    app/controllers/concerns/*.rb

Rails routes:

    config/routes.rb

Rails (Pundit) policies:

    app/policies/*.rb

React components (JS/JSX/HTML):

    app/javascript/components/*/

React entrypoint (load and initialize JS dependencies):

    app/javascript/packs/platform.js

Stylesheets (CSS/SCSS):

    app/assets/stylesheets/*

* *See the [CSS & Javascript Wiki](https://github.com/bebraven/platform/wiki/CSS-&-Javascript) for a TON more detail*

Tests:

    spec/*

### Adding new code

Rails has generators that let you add new code more easily by automatically creating the scaffolding
for the particular type of thing you are adding. Rails has a bunch of default generators you can use.
For example, to create a new model you can do:

    rails generate scaffold User name:string

which will create the model, migration, routes, views, controllers, tests, etc.

However, the default ones create a lot of cruft and things we don't use. Also, we can enforce our
project structure and make it easier to get any boilerplate in that matches how we've set things up
by creating our own generators. See [here](https://guides.rubyonrails.org/generators.html) for more info.

**TODO:** We have one custom generator that let's us take a model that we've defined and add scaffolding
that matches how the data-central project was structured. See [USAGE here](lib/generators/dscaffold/USAGE)
It is out of date and we're in the early stages of designing how the Braven Platform code will be structured
and work together. Update it and add more generators that make it easy to add code properly to our codebase.

#### Policies

We use [Pundit](https://github.com/varvet/pundit) for authorization. Each new controller should have
a corresponding policy with a matching name. For example, `controllers/new_things_controller.rb` would
have a policy called `NewThingPolicy` in a file `policies/new_thing_policy.rb` (note pluralization).

You can generate a new policy with:

    rails g pundit:policy NewThing

After creating a policy, you must explicitly call the `authorize` function in each action of the
controller, passing in the object to authorize against. Be as specific as possible. For example, in
a `show` action, you should have access to an instance of an object, so you should do:

    authorize @new_thing

Pundit will know to call `NewThingPolicy.show?`, passing in `@new_thing` as the scoped "record".
In an `index` view, you don't have access to a specific object instance, so you should scope to
the class itself:

    autorize NewThing

This will call `NewThingPolicy.index?` with the `NewThing` class as the scoped record. For more information,
check the Pundit README and API docs.

For an example policy for anonymous (no login) access, see `KeypairPolicy`. For an example controller
with no authorization, see `CasController`. For an example admin-only policy, see `CoursePolicy`.
For an example policy allowing any logged-in user, see `HoneycombJsPolicy`.

There is a global `after_action` callback in `ApplicationPolicy`, `verify_authorized` thats only purpose is
to serve as a reminder to call `authorize` in each controller action. If you see
`Pundit::AuthorizationNotPerformedError` while developing, it just means you haven't added an `authorize`
call to that action. See the comment in application controller for more information.

##### Policy specs

You'll find some policy specs in `spec/policies` - Pundit has some helpers that make writing tests easier, and
outside that you can just use regular ruby/rspec. An important note when writing policy specs - you **must** have
an actual `user` and `section` in the database if you are adding scoped roles like `user.add_role :admin, section`.
The roles code uses polymorphic relations in the `roles` table to associate these things, and will *seem to work,
but not behave correctly* if you only have local objects. For example, this is bad:

    # BAD - don't do this!
    section = Section.new
    user = User.new
    user.add_role :student, section

You must instead use:

    # Good - do this instead!
    section = create(:section)
    user = create(:registered_user)
    user.add_role :student, section

The first code won't error, it will just let your tests pass even if they're wrong.

##### Roles

We use [Rolify](https://github.com/RolifyCommunity/rolify) alongside Pundit to grant permissions based on a user's
"role". Roles are dynamic, stored in the `roles` table, so you won't find a list of valid roles anywhere in the
code. We can assign roles globally, like `user.add_role :admin`, or scoped to a specific object, like
`user.add_role :student, section`. The object relationship is polymorphic, and can point to any object that has
the `resourcify` call in its class definition. (See `app/models/section.rb` for an example.) We "resourcify"
sections rather than courses because we need to make decisions at a section level (see
`app/policies/lrs_xapi_proxy_policy.rb` for an example), and since sections are tied to a course, we don't
lose any information by doing so. It's also possible to assign roles scoped to a class, like
`user.add_role :student, Section`. See the Rolify README for more information on scopes.

### Email
In all environments other than production, we need to be careful not to email actual users. The following
environment variable ensures that

    MAILER_DELIVERY_OVERRIDE_ADDRESS=someaddress@example.com

When creating new outgoing emails, it's convenient to preview them as you work on them. See the following for
how we've [enabled previews](http://platformwe/rails/mailers/braven_devise_mailer) for the account creation
email flows:

    spec/mailers/previews/braven_devise_mailer_preview.rb

**TODO** talk about SMTP settings and what to do in the dev environment if you want real emails to go out so you
can view them in your email client.

### Troubleshooting

#### General
If something isn't working, you can watch the docker logs live with:

    docker-compose logs -f

Or search through them with e.g.:

    docker-compose logs | grep "ERROR_I_WANT_TO_SEE"

We also have the [web-console gem](https://github.com/rails/web-console)
in the dev env so that when you get an error page in the browser, it includes an interactive ruby console at the bottom
so that you can inspect the variables or run code. E.g. Type `instance_variables` or `local_variables` to see a list.
Or, for example you can inspect one such as the `@current_user` by writing `instance_variable_get(:@current_user)`

We also have the pry and rescue gems so that you can break and debug code. Here is an example for how to debug
a spec that is throwing an exception.

    bundle exec rescue rspec spec/a_failing_spec.rb --format documentation

See [this FANTASTIC article](https://supergood.software/a-ruby-gem-debugging-strategy/) for some general advice around
debugging and troubleshooting things if you're new to RoR development.

Of specific note, if you need to debug the code inside a gem, our gems are installed
at `vendor/bundle` inside the container. If you attach to the container you can dig down in there and add a
some logging inside the gem code. You have to restart the container for the change to be picked up and if you
make a mess of things and want to blow it away you need to remove the vendor-bundle volume using:

    docker volume rm platform_vendor-bundle

**NOTE:** pry doesn't currently work with our setup. Need to figure that out.

#### CKEditor
For troubleshooting ckeditor-specific issues in the content editor, append '?debug' to the URL:

    http://platformweb/course_contents/new?debug

That will attach the [CKEditor Inspector](https://ckeditor.com/docs/ckeditor5/latest/framework/guides/development-tools.html#ckeditor-5-inspector).

#### Development environment

If when you're running `docker-compose up -d` and running into "file not found"/"no such file/directory" errors, it could be a `LF/CRLF` issue that will cause the scripts to execute, for example, `/bin/bash^M`.

This is caused by `autocrlf=true` in your Git configuration.

Try re-cloning your repository with the flag:

    --config core.autocrlf=input

so it uses whatever exists in the repository instead of having Git control it.

You can also add the following to your `~/.gitconfig` and `./.git/config`or:

    [core]
        autocrlf = input

### Updating dependencies

To update Ruby dependencies, run:

    bundle update

To update JavaScript dependencies, run:

    yarn upgrade-interactive --latest

CKEditor updates tend to have major breaking changes often, so be sure to test and make sure everything still works.

From time to time, it may be useful to check for JS packages with known vulnerabilities. To do so, run:

    yarn audit

If there is anything to fix, you should be able to upgrade them automatically with:

    npx yarn-audit-fix

Once the dependencies are updated, you will need to rebuild your container:

    ./docker-compose/scripts/rebuild.sh

### Accessibility testing

This project includes [axe](https://www.deque.com/axe/) in development, for live, in-browser accessibility reporting.
Open your browser's console to view axe reports.

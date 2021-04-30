# TODO: write specs for the below: https://app.asana.com/0/1174274412967132/1200192173211416

# 1.) first time sign-up:
  # 1.a) no user in Canvas
    # confirmation email sent
    # can't login before using confirmation link
    # confirmation link confirms them and ...
      # auto-logs in and redirects to Canvas
      # allows future logins (registered at was done as part of sign-up)
    # blank confirmation_token fails to confirm them (but doesn't return a value indicating it failed)
    # wrong (not in DB) confirmation token fails to confirm them (but doesn't return a value indicating it failed)
    # trying to use an already consumed confirmation token asks them to log in (but doesn't reveal anything about the account or whether the token was valid)
    # Canvas API failures trying to make sure their email is in sync allows confirmation link to work after the API failure stops
    # manually change Canvas login email before confirmation. Confirmation updates Canvas email to match so that login works again
    # manually change Platform email so that it no longer matches Canvas. Confirmation updates Canvas email to match so that login works again
  # 1.b) manually add user to Canvas first (imagine a staff member is trying to get a TA access and doesn't follow the Sync process, we don't want things to fail with that email once we do it correctly)
    # repeat 1.a)

# 2.) with already confirmed user, change email:
  # Same stpes as 1.a) except the old email should work as the login email until they successfully use the confirmation link

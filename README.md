# Localnews
## Your self-hosted feed reader

### Example app
[localnews-example.herokuapp.com](https://localnews-example.herokuapp.com)

### Deploying on heroku

```bash
git clone https://github.com/bltavares/localnews.git
cd localnews
heroku create
heroku addons:add redistogo
git push heroku master
```

### Making the refresh a proccess in the background

```bash
heroku addons:add scheduler:standard 
heroku config:add PING_URL=https://<your-heroku-url>/refresh
heroku addons:open scheduler
```

Schedule the job on the Scheduler to run avery 10 minutes `rake ping`

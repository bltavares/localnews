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

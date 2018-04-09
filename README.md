### gh-missue -- Migrate Like a Boss!

[![DocStatus](https://inch-ci.org/github/E3V3A/gh-missue.svg?branch=master)](https://inch-ci.org/github/E3V3A/gh-missue)
[![GitHub last commit](https://img.shields.io/github/last-commit/E3V3A/gh-missue.svg)](https://github.com/E3V3A/gh-missue)
[![Maintenance](https://img.shields.io/badge/Maintained%3F-yes-green.svg)](https://GitHub.com/E3V3A/gh-missue/graphs/commit-activity)
[![Average time to resolve an issue](http://isitmaintained.com/badge/resolution/E3V3A/gh-missue.svg)](http://isitmaintained.com//project/E3V3A/gh-missue "Average time to resolve an issue")
[![Dependency Status](https://beta.gemnasium.com/badges/github.com/E3V3A/gh-missue.svg)](https://beta.gemnasium.com/projects/github.com/E3V3A/gh-missue)

A complete GitHub issue migration CLI tool written in Ruby.


| STATUS: | Version | Date | Maintained? |
|:------- |:------- |:---- |:----------- |
| Working | `1.0.1` | 2018-04-10 | YES |

---

**Q:** *What does `gh-missue` do?*

The primary use is for migrating selected issues from any one repository to another.
But it can do much more. You can also:

- Migrate *issues*, their labels and their comments in correct order.
- List any/all issues in any puplic repository
- List or migrate only issues selected by their *status*: `[all, open, closed]`
- List all available issue *labels* for any repository
- Copy all available issue *labels* for any repository, including: `name, color, description`.
- Use 3 different types of GitHub authentication: (*none, OAuth2 token, username/password*)
- Test your current GitHub request status showing your: *rate limit, ramining requests, quota refresh time*.
- Test your authentication token
- Learn about Ruby CLI options
- [ ] Decide to keep originally closed issues as closed or opened.
- [ ] Use the included class in your own tools


**Q:** *What does it **not** do?*

- Does not close issues on source repository after move
- Does not copy time-stamps. The new time is when the issue was moved.
- Does not copy issue-author. You will be the new author of all moved issues.
- Does not copy comment-authors. You will be the new author of all moved issue comments.
- Does not copy PR's. (But script can be easily modified to do so.)

**Q:** *Why is this needed?*

Sometimes, the structure of your project changes so drastically that it would break your repository.
You need an easy way to start from scratch and just commit everything to a new repository.
But, you've got all these valuable issues in the old repository on Github. 


**Q:** *Why are you using Ruby?*

I have never used Ryby until a few evenings ago. I came across an old library to migrate issues on github. 
However, it was half broken and extremely limited. But using a library sucked and I wanted a proper CLI 
that could handle large request rates. I decided to hack into it. Ruby is a nice and suprisingly robust 
language and it is still alive. Not surprsingly it is used by GitHub themselves.

You can read more about `Why Ruby isn't dead`: [here](https://www.engineyard.com/blog/ruby-still-isnt-dead) and 
[here](https://expertise.jetruby.com/is-ruby-on-rails-dead-2018-edition-407a618dab3a) and 
[here](https://www.tiobe.com/tiobe-index/ruby/).


**Q:** *Will I continue to support this tool?*

Sure, why not, but I will not spend any more time for new features. So if you wanna add something 
please send me a PR.

---

### Dependencies

This tool depends on:

- [1] [docopt](https://github.com/docopt/docopt.rb/)  -- For amazingly cool command line option handling
- [2] [octokit](https://github.com/octokit/octokit.rb/) -- For GitHub API access
- [3] [json]()  -- For pretty printing RESPONSE
- [4] [net/http]()  -- The cURL of Ruby 
- [5] [uri]() -- xxx


### Installation 


1. To make this run, you need to:  
   (a) have Ruby installed  
   (b) gem install GitHubs own "octokit" library  
   (c) gem install the option parser "docopt"
2. You should also consider creating a personal authentication token on GitHub,  
   to avoid getting rate-limited by a large number of requests in short time.

---

**Installing Ruby on a RPi3**

Installing Ruby on a Raspbian OS can be slightly tricky. There are essentailly 2 methods to do this.
1. Installing the APK package called `Ryby3`..
2. Installing Ruby from sources

I strongly recommend to use the first option, unless you plan to use Ruby a lot in the future, and to save a lot of time.


**Installing the native Ruby package:**

```bash
sudo apt-get install ruby2.3
sudo gem install bundler
```

**Installing the *gem* dependecies:**

```bash
sudo gem install octokit
sudo gem install docopt

# maybe I missed some others?
```


**Installing *gh-missue***

```bash
git clone https://github.com/E3V3A/gh-missue.git
cd gh-missue
bundle install

```


#### Bugs and Warnings

None

:information_source: For other bugs, issues, details and updates, please refer to the
[issue tracker](https://github.com/eouia/MMM-Assistant/issues).


#### Contribution

Feel free to post issues and PR's related to this tool.
Feel free to fork, break, fix and contribute. Enjoy!


### Recommended similar tools

* [github-issues-import](https://github.com/muff1nman/github-issues-import) and [mod](https://github.com/ericnewton76/github-issues-import) (Python)
* [github-issue-mover](https://github.com/google/github-issue-mover) (Dart)
* [offline-issues](https://github.com/jlord/offline-issues) (JS) -- To read issues offline
* []() ()
* []() ()

References:

* [Ruby in 20 minutes](https://www.ruby-lang.org/en/documentation/quickstart/)
* [Installing Ruby on Rail on RPi3](http://jeanbrito.com/2017/01/23/installing-ruby2-4-on-rails5-environment-on-raspberry-pi-3/)


---

Essential GitHub API documents:

* [Labels-used-for-issues](https://github.com/dotnet/roslyn/wiki/Labels-used-for-issues)
* https://developer.github.com/v3/issues/
* https://developer.github.com/v3/issues/labels/
* https://developer.github.com/v3/issues/labels/#get-a-single-label
* https://developer.github.com/v3/issues/#list-issues-for-a-repository
* https://developer.github.com/v3/guides/best-practices-for-integrators/#dealing-with-rate-limits

* https://developer.github.com/v3/#abuse-rate-limits
* https://developer.github.com/v3/#rate-limiting
* https://developer.github.com/v3/rate_limit/
* https://developer.github.com/v4/guides/resource-limitations/
* https://developer.github.com/v3/#increasing-the-unauthenticated-rate-limit-for-oauth-applications


---

#### Credits

Most grateful thanks to:
* [---](https://github.com/---/) - for clarifying and fixing XXXX

---

#### License

[![GitHub license](https://img.shields.io/github/license/E3V3A/gh-missue.svg)](https://github.com/E3V3A/gh-missue/blob/master/LICENSE)

A license to :sparkling_heart:!


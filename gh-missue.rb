#!/usr/bin/env ruby
# gh-missue.rb -- A GitHub issue migration script written in Ruby
#==================================================================================================
# Author:       E:V:A
# Date:         2018-04-10
# Change:       2022-01-25
# Version:      1.0.2
# License:      ISC
# Formatting    UTF-8 with 4-space TAB stops and no TAB chars.
# URL:          https://github.com/E3V3A/gh-missue
# Based On:     https://github.com/TimothyBritt/github-issue-migrate
# 
# Description:  A Ruby script for migrating selected GitHub issues to your own repository and 
#               using OAuth2 authentication to increase speed and prevent rate limiting.
#
# Dependencies:
#       [1] docopt  https://github.com/docopt/docopt.rb/        # option parser
#       [2] octokit https://github.com/octokit/octokit.rb/      # GitHubs API library
# 
# NOTE:
#
#   1. To make this run, you need to install Ruby with:
#           (a) winget install ruby
#           (b) gem install octokit
#           (c) gem install docopt
#
#   2. Clone latest version of this file
# 
#   3. You should also consider creating a personal authentication token on GitHub,
#      to avoid getting rate-limited by a large number of requests in short time.
#
# ToDo: 
#   
#   [ ] Add -a option to NOT copy original author & URL into migrated issue
#   [ ] Fix username/password authentication ?? (Maybe Deprecated?)
#   [ ] Check environment variable for OAUTH token:   
#       access_token = "#{ENV['GITHUB_OAUTH_TOKEN']}"
#   [ ] Fix inclusion of CLI options: -d, -n  
#       -d              - show debug info with full option list, raw requests & responses etc.
#       -n  <1,3-6,9>   - only migrate issues given by the list. Can be a range.
#   [/] Fix new Authentication issues
#   [ ] Make the issue vs PR selection smarter! 
#       - Now it just takes ALL and filters using list_source_issues()
#   [ ] ? Add <type> option to selec pr, vs issue:  '-p <type>'   where <type> = [issue, pr]
# 
# References:
# 
#   [1] https://developer.github.com/changes/2020-02-10-deprecating-auth-through-query-param/
#   [2] https://docs.github.com/en/developers/apps/building-oauth-apps/authorizing-oauth-apps#web-application-flow
#   [3] 
# 
#==================================================================================================
require 'docopt'
require 'octokit'
require 'net/http'
require 'json'

VERSION = '1.0.2'
options = {}

#--------------------------------------------------------------------------------------------------
# The cli options parser
#--------------------------------------------------------------------------------------------------
doc = <<DOCOPT

  Description:

    gh-missue is a Ruby program that migrate issues from one github repository to another.
    Please note that you can only migrate issues to your own repo, unless you have an OAuth2
    authentication token.

  Usage:
        #{__FILE__} [-c | -n <ilist> | -t <itype>] <source_repo> <target_repo>
        #{__FILE__} [-c | -n <ilist> | -t <itype>] <oauth2_token> <source_repo> <target_repo>
        #{__FILE__} [-c | -n <ilist> | -t <itype>] <username> <password> <source_repo> <target_repo>
        #{__FILE__} [-d] -l <itype> [<oauth2_token>] <repo>
        #{__FILE__} -n <ilist>
        #{__FILE__} -t <itype>
        #{__FILE__} [-d] -r [<oauth2_token>]
        #{__FILE__} -d
        #{__FILE__} -v
        #{__FILE__} -h

  Options:

        -c                  - only copy all issue labels from <source> to <target> repos, including name, color and description
        -l <itype> <repo>   - list available issues of type <itype> (all,open,closed) and all labels in repository <repo>
        -t <itype>          - specify what type (all,open,closed) of issues to migrate. [default: open]
        -r                  - show current rate limit and authentication method for your IP
        -d                  - show debug info with full option list, raw requests & responses etc.
        -n <ilist>          - only migrate issues with comma separated numbers given by the list. Can include a range.
        -h, --help          - show this help message and exit
        -v, --version       - show version and exit

  Examples:

        #{__FILE__} -r
        #{__FILE__} -l open E3V3A/MMM-VOX
        #{__FILE__} -t closed "E3V3A/TESTO" "USERNAME/REPO"
        #{__FILE__} -n 1,4-5 "E3V3A/TESTO" "USERNAME/REPO"

  Dependencies:
        #{__FILE__} depends on the following gem packages: octokit, docopt.

DOCOPT

#--------------------------------------------------------------------------------------------------
# The IssueMigrator
#--------------------------------------------------------------------------------------------------
class IssueMigrator

    # attr_accessor :issues, :client, :target_repo, :source_repo
    attr_accessor :access_token, :issues, :ilist, :itype, :client, :target_repo, :source_repo

    def hex2rgb(hex)
        # Usage: print hex2rgb("d73a4a") - prints a RGB colored box from hex
        r,g,b = hex.match(/^(..)(..)(..)$/).captures.map(&:hex)
        s = "\e[48;2;#{r};#{g};#{b}m  \e[0m"
    end
    
    # curl -v -H "Authorization: token <MY-40-CHAR-TOKEN>" \ 
    #         -H "Accept: application/vnd.github.v3+json" https://api.github.com/repos/E3V3A/gh-missue/issues
    def initialize(access_token, source_repo, target_repo)
        @client = Octokit::Client.new( 
            :access_token => access_token,
            :accept => 'application/vnd.github.v3+json',
            :headers => { "Authorization" => "token " + access_token },
            # :headers => { "X-GitHub-OTP" => "<your 2FA token>" }

            # // Personal OAuth2 Access Token
            #:access_token => "YOUR_40_CHAR_OATH2_TOKEN"

            # // OAuth2 App Credentials  (DEPRECATED!)
            # NEW use:  
            # curl -u my_client_id:my_client_secret https://api.github.com/user/repos
            #:client_id     => "<YOUR_20_CHAR_OATH2_ID>",
            #:client_secret => "<YOUR_40_CHAR_OATH2_SECRET>"
            
            per_page: 100 
        )
        user = client.user
        user.login
        @source_repo = source_repo
        @target_repo = target_repo
        @itype = itype
    end

    def pull_source_issues(itype) # ilist => nil ??
        @client.auto_paginate = true
        @issues = @client.issues(@source_repo, :state => itype)     # The issue type:   <itype>: [open/closed/all]
        # @issues = @client.issues(@source_repo, :issue => ilist)   # The issue list:   <ilist>: "1,2,5-7,19"
        puts "Found #{issues.size} issues of type: #{itype}\n"
    end

    def list_source_issues(itype)
        pull_source_issues(itype)
        @issues.each do |source_issue|
            #puts "[#{source_issue.number}]\t  #{source_issue.title}"
            puts "[#{source_issue.number}]".ljust(10) + "#{source_issue.title}"
        end
        puts
    end

    def list_source_labels
        @client.auto_paginate = true
        @labels = @client.labels(@source_repo.freeze, accept: 'application/vnd.github.symmetra-preview+json')
        puts "Found #{@labels.size} issue labels:"
        # ToDo: check and handle length (in case > 20)
        @labels.each do |label|
            # ToDo:  Add "  " colored "boxes" using the color of the tag.
            color_box = hex2rgb("#{label.color}") + "  "
            #puts "[#{label.color}]  " + "#{label.name}".ljust(20) + ": #{label.description}"
            puts "[#{label.color}]  " + color_box + "#{label.name}".ljust(20) + ": #{label.description}"
        end
        puts
    end

    def create_target_labels
        @client.auto_paginate = true
        @source_labels = @client.labels(@source_repo.freeze, accept: 'application/vnd.github.symmetra-preview+json')
        # @target_labels = @client.add_label(@target_repo.freeze, accept: 'application/vnd.github.symmetra-preview+json')
        puts "Found #{@source_labels.size} issue labels in <source_repo>:"
        puts "Copying labels..."
        tlabel = "" # nil
        @source_labels.each do |lbl|
            # ToDo:  Add "  " colored "boxes" using the color of the tag.
            #puts "[#{lbl.color}]  #{lbl.name} :  #{lbl.description}"
            puts "[#{lbl.color}]  " + "#{lbl.name}".ljust(20) + ": #{lbl.description}"
            #tlabel = {"name": lbl.name, "description": lbl.description, "color": lbl.color}
            #tlabel = {lbl.name, lbl.color, description: lbl.description}
            #lab = client.add_label(@target_repo.freeze, accept: 'application/vnd.github.symmetra-preview+json', tlabel)
            lab = client.add_label(@target_repo.freeze, lbl.name, lbl.color, accept: 'application/vnd.github.symmetra-preview+json', description: lbl.description)
            sleep(2)
        end
        puts "done."
    end

    def push_issues
        @issues.reverse!
        n = 0
        @issues.each do |source_issue|
            n += 1
            print "Processing issue: #{source_issue.number}  (#{n}/#{issues.size})\r"
            source_labels = get_source_labels(source_issue)
            source_comments = get_source_comments(source_issue)
            if !source_issue.key?(:pull_request) || source_issue.pull_request.empty?

                # PR#2
                issue_body = "*Originally created by @#{source_issue.user[:login]} (#{source_issue.html_url}):*\n\n#{source_issue.body}"
                target_issue = @client.create_issue(@target_repo, source_issue.title, issue_body, {labels: source_labels})

                #target_issue = @client.create_issue(@target_repo, source_issue.title, source_issue.body, {labels: source_labels})

                push_comments(target_issue, source_comments) unless source_comments.empty?
                @client.close_issue(@target_repo, target_issue.number) if source_issue.state === 'closed'
            end
            # We need to set a rate limit, even for OA2, it is 0.5 [req/sec]
            sleep(90) if ( issues.size > 1 ) # [sec]
        end
        puts "\n"
    end

    # API bug:  missing color/description
    def get_source_labels(source_issue)
        labels = []
        source_issue.labels.each do |lbl|
            labels << {"name": lbl.name, "description": lbl.description, "color": lbl.color}
        end
        #puts "Labels: #{labels}"
        labels
    end

    def get_source_comments(source_issue)
        comments = []
        source_comments = @client.issue_comments(@source_repo, source_issue.number)
        source_comments.each do |cmt|
            comments << cmt.body
        end
        comments
    end

    def push_comments(target_issue, source_comments)
        source_comments.each do |cmt|
            @client.add_comment(@target_repo, target_issue.number, cmt)
        end
    end
end

#--------------------------------------------------------------------------------------------------
# MAIN
#--------------------------------------------------------------------------------------------------

#if __FILE__ == $0
begin

    hLine = "-"*72
    puts

    def sort_list(ilist)
        # "12,3-5,2,6,35-38" --> [2,3,4,5,6,12,35,36,37,38]
        ilist.gsub(/(\d+)-(\d+)/) { ($1..$2).to_a.join(',') }.split(',').map(&:to_i).sort.uniq
    end

    #----------------------------------------------------------------------
    # CLI Options
    #----------------------------------------------------------------------
    options = Docopt::docopt(doc, version: VERSION) # help: true

    if options['-d']
        debug = true
        #pp Docopt::docopt(doc, version: VERSION)
        puts "\nAvailable options are:\n#{options.inspect}\n"
        puts "\nThe supplied CLI options were:\n#{ARGV.inspect}\n\n"
    end

    if options['<oauth2_token>'] 
        access_token = options['<oauth2_token>']
        if access_token.size != 40 
            puts "Error: The github access token has to be 40 characters long!"
            puts "       (Yours was: #{access_token.size} characters.)"
            exit
        else 
            puts "Using access_token: #{access_token}" if options['-d']
        end
    end

    # -l <itype> <source_repo>
    # https://docs.github.com/en/rest/reference/issues#list-repository-issues
    # GET /repos/{owner}/{repo}/issues
    # curl -v -H "Authorization: token <MY-40-CHAR-TOKEN>" \ 
    #         -H "Accept: application/vnd.github.v3+json" https://api.github.com/repos/E3V3A/gh-missue/issues
    if ( options['-l'] )
        itype = options['-l']
        source_repo = options['<repo>']
        target_repo = "E3V3A/TESTT" # a dummy repo
        im = IssueMigrator.new("#{access_token}", "#{source_repo}", "#{target_repo}")
        im.list_source_issues(itype)
        im.list_source_labels
    end

    # -n <ilist>
    if ( options['-n'] )
        ilist = options['-n']
        puts "The \"-n\" option has not yet been implemented!"
        puts "The supplied issue list: #{ilist}"
        #sorted = ilist.split(",").sort_by(&:to_i)
        sorted = sort_list(ilist)
        puts "The sorted issue list  : #{sorted}"
    end

    # -r 
    # https://docs.github.com/en/rest/reference/rate-limit
    # NEW:  curl -H "Accept: application/vnd.github.v3+json" https://api.github.com/rate_limit
    #       curl -H "Accept: application/vnd.github.v3+json" \ 
    #            -H "Authorization: token <MY-40-CHAR-TOKEN>" https://api.github.com/rate_limit

    if ( options['-r'] )

        #access_token = "#{ENV['GITHUB_OAUTH_TOKEN']}"
        #access_token = "<MY-40-CHAR-TOKEN>"

        url = URI("https://api.github.com/rate_limit")
        http = Net::HTTP.new(url.host, url.port)
        http.use_ssl = true

        req = Net::HTTP::Get.new(url)
        req["User-Agent"] = "gh-missue"
        req["Accept"]     = "application/vnd.github.v3+json"

        if (access_token)
            puts "Using access_token: #{access_token}" 
            req["Authorization"] = "token #{access_token}" 
        end

        res = http.request(req) 
        
        if (debug)
            puts res.read_body
        end
        
        if (res.message != "OK")    # 200
            puts "ERROR: Bad reponse code: #{res.code}\n"
            puts res.body
        else
            #debug = false
            if (debug)
                puts hLine + "\nResponse Headers:\n" + hLine
                puts "#{res.to_hash.inspect}\n"
                puts hLine + "\nBody:\n" + hLine
                puts "#{res.body}\n" + hLine
            end

            #----------------------------------------------------------------------
            # NEW:  resources: {core, graphql, integration_manifest, search }
            #       (There are more!)
            # Rate Limit Status:
            # core                  : for all non-search-related resources in the REST API.
            # search                : for the Search API.
            # graphql               : for the GraphQL API.
            # integration_manifest  : for the GitHub App Manifest code conversion endpoint.
            #----------------------------------------------------------------------
            rbr = JSON.parse(res.body)['resources']['core']
            RTc = Time.at(rbr['reset'])
            puts "\nCore"
            puts "  Rate limit   : #{rbr['limit']}"
            puts "  Remaining    : #{rbr['remaining']}"
            puts "  Refresh at   : #{RTc}"
            puts "Search"
            rbs = JSON.parse(res.body)['resources']['search']
            RTs = Time.at(rbs['reset'])
            puts "  Search limit : #{rbs['limit']}"
            puts "  Remaining    : #{rbs['remaining']}"
            puts "  Refresh at   : #{RTs}"
        end
    end
    
    # MAIN
    if ( options['<source_repo>'] and options['<target_repo>'] )
        itype = options['-t']
        #ilist = options['-n']
        #puts "<itype>: #{itype}"  # debug
        source_repo = options['<source_repo>']
        target_repo = options['<target_repo>']
        im = IssueMigrator.new("#{access_token}", "#{source_repo}", "#{target_repo}")
        if options['-c']
            im.create_target_labels
            exit
        end
        #exit if options['-c']
        im.pull_source_issues(itype)    # add ilist
        #im.list_source_issues(itype)   # 
        im.push_issues
    end

rescue Docopt::Exit => e
    puts e.message
    #puts e.backtrace.inspect
end

puts "\nDone!\n"

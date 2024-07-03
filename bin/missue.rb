#!/usr/bin/env ruby
# gh-missue.rb -- A GitHub issue migration script written in Ruby
#==================================================================================================
# Author:       E:V:A
# Date:         2018-04-10
# Change:       2022-01-28
# Version:      1.0.3
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
# Development Notes:
#
#   - To print new lines, you have to use "\n", not '\n'.
#   - Ruby function options template:
#       def testing(a, b = 1, *c, d: 1, **x)  { p a,b,c,d,x }
#       testing('a', 'b', 'c', 'd', 'e', d: 2, x: 1) 
#       # => ["a", "b", ["c", "d", "e"], 2, {:x=>1}]
#
# Installation:
# 
#   1. To make this run, you need to install Ruby with:
#           (a) winget install ruby
#           (b) gem install octokit
#           (c) gem install docopt
#           (d) gem install missue
#
#   2. You also have to create a personal authentication token on GitHub, in order 
#      to copy and avoid getting rate-limited by a large number of requests in short time.
#
# ToDo: 
#   
#   [ ] Add pagination handling in repo_access():
#       https://github.com/octokit/octokit.rb/issues/732
#   [ ] Write a more efficient pull_source_issues()  (Now using ~6 requests per moved issue?)
#   [ ] Switch meaning of (itype vs. istat): "itype" should be [issue, pr] and "istat" should be [open,closed,all].
#   [ ] Add -o option to NOT copy original author & URL into migrated issue
#   [ ] Add -k option to copy previously 'closed' issues as 'open' [keep, open, closed]
#   [ ] Add -a put this as a CLI option for showing repo_access()
#   [ ] Add -p <itype> option to select only pr vs issue. <itype> = [issue, pr]
#   [ ] Make the issue vs PR selection smarter! 
#       - Now it just takes ALL and filters using list_source_issues()
# 
# References:
# 
#   [1] https://developer.github.com/changes/2020-02-10-deprecating-auth-through-query-param/
#   [2] https://docs.github.com/en/developers/apps/building-oauth-apps/authorizing-oauth-apps#web-application-flow
#   [3] https://stackoverflow.com/questions/3219229/why-does-array-slice-behave-differently-for-length-n
# 
#==================================================================================================
require 'pathname'
require 'docopt'
require 'octokit'
require 'net/http'
require 'json'

VERSION = '1.0.3'
options = {}

# Remap __FILE__ to avoid long path on '-h' help page
# NOTE: We could also use: $0 - The name of the ruby script file currently executing
#       puts "File: #{$0}" # Same problem!
pn = Pathname.new(__FILE__)
__BASE__ = pn.basename

#--------------------------------------------------------------------------------------------------
# The cli options parser
#--------------------------------------------------------------------------------------------------
# Usage: http://docopt.org/
# Use parenthesis "( )" to group elements when one of the mutually exclusive cases is required. 
# Use brackets "[ ]" to group elements when none of the mutually exclusive cases is required.
# 
#--------------------------------------------------------------------------------------------------
doc = <<DOCOPT
.
  Description:

    gh-missue is a Ruby program that bulk migrate issues from one github repository to another.
    Please note that you can only migrate issues to your own repo, unless you have an OAuth2
    authentication token. You can also list all the open or closed issues and PR's along with 
    the colored labels. It also include the original author's name and URL of the issues copied.
    The <oauth2_token> can be omitted if it is defined in the 'GITHUB_OAUTH_TOKEN' environmental 
    variable.

  Usage:
        #{__BASE__} -c [<oauth2_token>] <source_repo> <target_repo>
        #{__BASE__} [-d] -n <ilist> [<oauth2_token>] <source_repo> <target_repo>
        #{__BASE__} [-d] -t <itype> [<oauth2_token>] <source_repo> <target_repo>
        #{__BASE__} [-d] -l <itype> [<oauth2_token>] <repo>
        #{__BASE__} [-d] -r [<oauth2_token>]
        #{__BASE__} -a [<oauth2_token>]
        #{__BASE__} -v
        #{__BASE__} -h

  Options:

        -a                  - show your Read/Write accees status on all your repositories. 
        -c                  - copy (only) the issue labels from <source> to <target> repos, including name, color and description.
        -l <itype> <repo>   - list all issues of type <itype> (all, open, closed) and all labels in repository <repo>
        -n <ilist>          - only migrate specific issues given by a comma separated list of numbers, including ranges.
        -t <itype>          - specify the type of issues to migrate. [default: open]
        -r                  - show current rate limit and authentication method for your IP
        -d                  - show debug info with full option list, raw requests & responses etc.
        -h, --help          - show this help message and exit
        -v, --version       - show version and exit

  Examples:

        #{__BASE__} -r
        #{__BASE__} -l open E3V3A/gh-missue
        #{__BASE__} -t closed "E3V3A/TESTO" "USERNAME/REPO"
        #{__BASE__} -n 1,4-5 "E3V3A/TESTO" "USERNAME/REPO"

  Dependencies:
        #{__BASE__} depends on the following gem packages: octokit, docopt.

  Bugs or Issues?
        Please report bugs or issues here:
        https://github.com/E3V3A/gh-missue
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
    
    def getToken
        access_token = "#{ENV['GITHUB_OAUTH_TOKEN']}" # @access_token ???
    end

    # curl -v -H "Authorization: token <MY-40-CHAR-TOKEN>" \ 
    #         -H "Accept: application/vnd.github.v3+json" https://api.github.com/repos/E3V3A/gh-missue/issues
    def initialize(access_token, source_repo, target_repo)
        @client = Octokit::Client.new( 
            :access_token => access_token,
            :accept       => 'application/vnd.github.v3+json',
            :headers      => { "Authorization" => "token " + access_token },
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
        @ilist = ilist      # 2022-01-27 18:48:35
    end

    def pull_source_issues(itype, ilist = nil)
        @client.auto_paginate = true

        puts "\n  <itype>: #{itype}"
        puts "  <ilist>: #{ilist}\n"

        # itype is a constant, while ilist is a list, so we need to iterate
        # The issue list:   <ilist>: "1,2,5-7,19"
        if itype
            @issues = @client.issues(@source_repo, :state => itype)     # The issue type:   <itype>: [open/closed/all]
        elsif ilist
            #@issues = @client.issues(@source_repo, :state => 'all')
            
            #@issues.each do |source_issue|
            #    print "Processing issue: #{source_issue.number}  (#{n}/#{issues.size})\r"
            #    if !source_issue.key?(:pull_request) || source_issue.pull_request.empty?
            #       #
            #    end
            #end

            puts
            my_array = []
            ilist.each do |i|
                puts "Adding issue [#]: #{i} \t from: #{@source_repo}\n"
                my_array.push(@client.issue(@source_repo.freeze, "#{i}", accept: 'application/vnd.github.v3+json', :state => 'all'))
                #@issues.push(@client.issue(@source_repo.freeze, "#{i}", accept: 'application/vnd.github.v3+json', :state => 'all'))
            end
            @issues = my_array
        end
        
        opa = "#{@issues}".split(',').join(",\n")
        puts "\n\n#{opa}\n\n" if $debug
        
        # ToDo: "itype" should be [issue, pr] and "istat" should be [open,closed,all].
        puts "\nFound #{issues.size} issues of status: #{itype}\n"
    end

    def list_source_issues(itype)
        pull_source_issues(itype)
        @issues.each do |source_issue|
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
            color_box = hex2rgb("#{label.color}") + "  "
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
	    color_box = hex2rgb("#{lbl.color}") + "  "
            #puts "[#{lbl.color}]  " + "#{lbl.name}".ljust(20) + ": #{lbl.description}"
            puts "[#{lbl.color}]  " + color_box + "#{lbl.name}".ljust(20) + ": #{lbl.description}"
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
            print "Pushing issue: #{source_issue.number}  (#{n}/#{issues.size})\r"
            source_labels = get_source_labels(source_issue)
            source_comments = get_source_comments(source_issue)

            # Only push if not a PR || empy         ??? 2022-01-27 19:42:37
            if !source_issue.key?(:pull_request) || source_issue.pull_request.empty?

                # PR#2
                issue_body = "*Originally created by @#{source_issue.user[:login]} (#{source_issue.html_url}):*\n\n#{source_issue.body}"
                target_issue = @client.create_issue(@target_repo, source_issue.title, issue_body, {labels: source_labels})

                push_comments(target_issue, source_comments) unless source_comments.empty?
                
                # Close target issue IF it was already closed!
                # ToDo: -k switch!
                @client.close_issue(@target_repo, target_issue.number) if source_issue.state === 'closed'
            end
            # We need to set a rate limit, even for OA2, it is 0.5 [req/sec]
            sleep(5) if ( issues.size > 1 ) # [sec]
        end
        puts "\n"
    end

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
begin

    hLine = "-"*72
    puts

    def sort_list(ilist)
        # "12,3-5,2,6,35-38" --> [2,3,4,5,6,12,35,36,37,38]
        ilist.gsub(/(\d+)-(\d+)/) { ($1..$2).to_a.join(',') }.split(',').map(&:to_i).sort.uniq
    end

    # ToDo: Add pagination handling!
    def repo_access
        hLine = "-"*72
        redW = "\e[1;49;31mW\e[0m"      # red W
        yelR = "\e[1;49;33mR\e[0m"      # yel R    
        grnR = "\e[1;49;32mR\e[0m"      # grn R    
        client = Octokit::Client.new(access_token: ENV['GITHUB_OAUTH_TOKEN'], accept: 'application/vnd.github.v3+json')
        puts "\n" + hLine + "\n Repo Access\n" + hLine
        client.repositories.each do |repository|
            full_name       = repository[:full_name]
            has_push_access = repository[:permissions][:push]
            access_type = has_push_access ? redW : grnR
            puts "  #{access_type}  : #{full_name}"
        end
        
        puts "\n" + hLine + "\n Organizations\n" + hLine
        client.organizations.each do |organization|
            puts "  #{organization[:login]}"
        end
        puts hLine
    end

    #----------------------------------------------------------------------
    # CLI Options
    #----------------------------------------------------------------------
    options = Docopt::docopt(doc, version: VERSION) # help: true

    # Should never get here if docopt is set correcly
    #if ( options['-n'] && options['-t'] ) 
    #    puts "\n  ERROR: You cannot use both '-n' and '-t' options at the same time!\n"
    #    exit
    #end

    if options['-a']
        repo_access
    end

    if options['-d']
        debug = true
        opa = "#{options.inspect}".split(',').join("\n")
        #puts "\nAvailable options are:\n#{options.inspect}\n"
        puts "\nAvailable options are:\n#{opa}\n"
        puts "\nThe supplied CLI options were:\n#{ARGV.inspect}\n\n"
    end

    # This is possibly fucking up things, since it doesn't have an option flag.
    # Perhaps add '-u' <token> as a new flag?
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
        #puts "The \"-n\" option has not yet been implemented!"
        #puts "The supplied issue list: #{ilist}"
        sorted = sort_list(ilist)
        puts "The sorted issue list  : #{sorted}"
        @ilist = sorted
    end

    # -r 
    # https://docs.github.com/en/rest/reference/rate-limit
    # NEW:  curl -H "Accept: application/vnd.github.v3+json" https://api.github.com/rate_limit
    #       curl -H "Accept: application/vnd.github.v3+json" \ 
    #            -H "Authorization: token <MY-40-CHAR-TOKEN>" https://api.github.com/rate_limit

    if ( options['-r'] )

        url = URI("https://api.github.com/rate_limit")
        http = Net::HTTP.new(url.host, url.port)
        http.use_ssl = true

        req = Net::HTTP::Get.new(url)
        req["User-Agent"] = "gh-missue"
        req["Accept"]     = "application/vnd.github.v3+json"

        # Try to get token from ENV
        if not (access_token)
            access_token = "#{ENV['GITHUB_OAUTH_TOKEN']}"
            if (access_token == "")
                access_token = nil
                puts "No token found: using basic access"
            end
        end

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

            # ToDo: put this as a CLI option
            #repo_access # This is using 1 request to complete!

        end
    end
    
    #------------------------------------------------------------
    # MAIN - Do the migration 
    #------------------------------------------------------------
    # "and" or && ?? 2022-01-27 17:26:14
    if ( options['<source_repo>'] and options['<target_repo>'] )
        itype = options['-t']
        #ilist = options['-n']
        
        puts "\n<itype>: #{itype}"  if debug
        puts "<ilist>: #{ilist}\n"  if debug

        source_repo = options['<source_repo>']
        target_repo = options['<target_repo>']
        im = IssueMigrator.new("#{access_token}", "#{source_repo}", "#{target_repo}")
        
        if options['-c']
            im.create_target_labels
            exit
        end
        
        if ilist
            itype = nil
            ilist = sort_list(ilist)
            im.pull_source_issues(itype, ilist)
        else
            im.pull_source_issues(itype)
        end

        #im.pull_source_issues(itype)    # add ilist
        ##im.list_source_issues(itype)   # 
        im.push_issues
    end

rescue Docopt::Exit => e
    puts e.message
    #puts e.backtrace.inspect
end

puts "\nDone!\n"

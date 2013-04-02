#!/usr/bin/env ruby
# encoding: utf-8
require 'rubygems'
require 'sinatra'
require 'slim'
require 'mongo'
require 'grit'
require 'pp'
include Grit

# enable session
#set :session, true

get '/' do
    connection = Mongo::Connection.new
    @commits_arr = []
    db = connection.db('t_committer_user')
    db.collection_names.each do |user|
      coll = db.collection(user)
      @commits_arr << {:user => user, :count => coll.count}
    end

    @commits_arr.delete_if{|x| x[:user] == 'system.indexes'}
    @commits_arr.sort! {|a, b| b[:count] <=> a[:count]}

    slim :index
end

get '/update' do
  # mongo connection
  connection = Mongo::Connection.new

  # deal with git
  DIR = "/tmp"
  repo_keys = ["job-enjoy"]
  repo_keys.each do |repo_key|
    repo_path = File.join(DIR, repo_key)
    if File.exist?(repo_path)
      repo = Grit::Repo.new(repo_path)
    else
      repo = Grit::Git.new("")
      repo.clone({:quiet => false, :verbose => true, :progress => false, :branch => 'master', :timeout => false}, "https://github.com/nabuchi/#{repo_key}.git", repo_path)
      repo = Grit::Repo.new(repo_path)
    end
    db_repo = connection.db('t_committer_repo')
    db_user = connection.db('t_committer_user')
    coll_repo = db_repo.collection(repo_key)

    #get recently commit hash from coll_repo
    commits = coll_repo.find.sort([:committed_date, :desc])
    current_id = ""
    if commits.count > 0
      current_id = commits.first["id"]
    end

    repo.commits('master', 100).each do |c|
      p current_id, c.id
      break if current_id == c.id
      doc = {:id            => c.id,
             :repo_key       => repo_key,
             :committed_date => c.committed_date.strftime("%Y-%m-%d %H:%M:%S"),
             :author         => c.author.name,
             :author_email   => c.author.email,
             :message        => c.message,
            }
      coll_user = db_user.collection(c.author.name)
      coll_repo.insert(doc)
      coll_user.insert(doc)
    end
  end
end

module MCollective
  module Agent
    class Gitagent<RPC::Agent

      require 'yaml'
      require 'fluent-logger'
      require 'securerandom'

      class CmdException<Exception;end;
      class CmdExecuteException<Exception;end;
      class GitException<Exception;end;

      activate_when do
        File.exists?('/etc/facter/facts.d/git_configure.yaml')
      end

      def local_log(tag,hash)
        Fluent::Logger::FluentLogger.open(nil, :host=>'localhost', :port=>24224)
        Fluent::Logger.post("gitagent.#{tag}", hash)
        msg = tag + ': ' + hash.inspect
        Log.info(msg)
      end

      def create_id
        request.data[:request_id] = SecureRandom.uuid
      end

      def check_file(file)
        if File.exists?(file) and File.executable?(file)
          return
        else
          raise CmdException, "#{file} does not exist or is not executable."
        end
      end

      def execute(shellcmd,tag,workdir)
        out = ''
        err = ''
        status = run("#{shellcmd} -t #{tag}", :stdout => out, :stderr => err, :cwd => workdir, :chomp => true)
        log = {'status' => status, 'stdout' => out, 'stderr' => err}
        local_log('execute',log)
        unless status == 0
          raise CmdExecuteException, log.to_s
        else
          return status,out,err
        end
      end

      def do_git(repo,sitedir,tag)
        out = ''
        err = ''
        gitcmd = "cd #{repo} && /usr/bin/git --work-tree=#{sitedir} checkout -f #{tag}"
        status = run("/bin/su - www-data -c \"#{gitcmd}\"", :stdout => out, :stderr => err, :cwd => repo, :chomp => true)
        local_log('gitcmd',{'command' => gitcmd, 'status' => status,'stdout' => out, 'stderr' => err})
        unless status == 0
          raise GitException, log
        else
          return status,out,err
        end
      end

      def write_tag(repo,tag)
        ltag = "Tag: #{tag}\n"
        tagfile = "#{repo}/TAG"
        File.open(tagfile, 'w') {|f| f.write(ltag) }
      end

      action 'git_tag' do
        validate :repo, String

        rconfig = YAML.load_file('/etc/facter/facts.d/git_configure.yaml')
        lrepo = rconfig["repo_#{request[:repo]}"]
        reply[:lrep] = lrepo

        count = request.data.fetch(:count) { nil }
        if count
          validate :count, Fixnum
          reply[:tstatus] = run("/usr/bin/git for-each-ref --format '%(refname)' --sort=-taggerdate --count=#{count} refs/tags", :stdout => :tout, :stderr => :err, :cwd => lrepo, :chomp => true)
          reply[:bstatus] = run("/usr/bin/git for-each-ref --format '%(refname)' --sort=-committerdate --count=#{count} refs/", :stdout => :bout, :stderr => :err, :cwd => lrepo, :chomp => true)
        else
          reply[:tstatus] = run('/usr/bin/git tag', :stdout => :tout, :stderr => :err, :cwd => lrepo, :chomp => true)
          reply[:bstatus] = run('/usr/bin/git branch -a', :stdout => :bout, :stderr => :err, :cwd => lrepo, :chomp => true)
        end
      end


      action 'git_state' do
        validate :repo, String

        rconfig = YAML.load_file('/etc/facter/facts.d/git_configure.yaml')
        lrepo = rconfig["repo_#{request[:repo]}"]
        reply[:lrep] = lrepo

        contents = File.read("#{lrepo}/TAG")
        reply[:tstate] = contents
      end

      action 'git_checkout' do
        validate :repo, String
        validate :tag, String

        create_id if request.data[:request_id] == nil

        rconfig = YAML.load_file('/etc/facter/facts.d/git_configure.yaml')

        lrepo = rconfig["repo_#{request[:repo]}"]
        lsite = rconfig["sitedir_#{request[:repo]}"]
        sitetype = rconfig["sitetype_#{request[:repo]}"]
        wdir = rconfig["controldir_#{request[:repo]}"]
        precmd = wdir + '/pre-deploy.sh'
        postcmd = wdir + '/post-deploy.sh'

        deploy_tag = request[:tag]

        reply[:lrep] = lrepo
        reply[:lsit] = lsite
        reply[:trub1] = precmd
        reply[:trub2] = postcmd

        checkout_log = {'tag' => deploy_tag,'repo' => lrepo,'target' => lsite, 'request' => request[:request_id], 'sitetype' => sitetype}
        local_log('deploy',checkout_log)

        begin
          check_file(precmd)
          check_file(postcmd)
          reply[:prstat],reply[:prout],reply[:prerr] = execute(precmd,deploy_tag,wdir)
          reply[:dstat],reply[:dout],reply[:derr] = do_git(lrepo,lsite,deploy_tag)
          reply[:postat],reply[:poout],reply[:poerr] = execute(postcmd,deploy_tag,wdir)
          write_tag(lrepo,deploy_tag)
          reply[:detail] = checkout_log.to_s
        rescue CmdException => e
          log = "Script check failed: #{e}"
          reply[:detail] = log
        rescue CmdExecuteException => e
          log = "Script execute failed: #{e}"
          reply[:detail] = log
        rescue GitException => e
          log = "Git failure: #{e}"
          reply[:detail] = log
        end
      end
    end
  end
end


module MCollective
  module Agent
    class Gitagent<RPC::Agent

      require 'yaml'
      require 'stomp'
      require 'syslog'
      require 'socket'

      class CmdException<Exception;end;
      class CmdExecuteException<Exception;end;
      class GitException<Exception;end;
      
      activate_when do
        File.exists?("/etc/facts.d/facts.yaml")
      end

      def create_id
        request.data[:request_id] = Digest::MD5.hexdigest request.data[:repo] + " " + request.data[:tag] + " " + "#{Time.now.to_i}"
      end

      def check_file(file)
        if File.exists?(file) and File.executable?(file)
          return
        else
          raise CmdException, "#{file} does not exist or is not executable."
        end
      end

      def execute(shellcmd,tag,workdir)
        out = ""
        err = ""
        status = run("#{shellcmd} -t #{tag}", :stdout => out, :stderr => err, :cwd => workdir, :chomp => true)
        log = "#{shellcmd} status: #{status} stdout: #{out} stderr: #{err}"
        Log.info(log)
        if status != 0
          raise CmdExecuteException, log
        else
          return status,out,err
        end
      end

      def do_git(repo,sitedir,tag)
        out = ""
        err = ""
        gitcmd = "cd #{repo} && /usr/bin/git --work-tree=#{sitedir} checkout -f #{tag}"
        status = run("/bin/su - www-data -c \"#{gitcmd}\"", :stdout => out, :stderr => err, :cwd => repo, :chomp => true)
        log = "git-command #{gitcmd} exited with status: #{status} stdout: #{out} stderr: #{err}"
        Log.info(log)
        if status != 0
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

      def stomp_log(repo,site,tag,rid,sitetype)
        host_name = Socket::gethostname
        eventdetail = "git-agent on #{host_name} checked out tag #{tag} from repo #{repo} to target #{site} request id #{rid} type #{sitetype}"
        Log.info(eventdetail)

        stompconfig = '/usr/share/mcollective/plugins/mcollective/agent/git-agent.yaml'
        if File.exists?(stompconfig)
          sconfig = YAML.load_file(stompconfig)
          stompconnector = sconfig['stompconnector']

          sclient = Stomp::Client.new(stompconnector)
          if sclient
            report_topic = sconfig["report-topic"]
            sclient.publish("/topic/#{report_topic}",eventdetail, {:subject => "Talking to eventbot"})
            sclient.close
          end
        end
        return eventdetail
      end

      action "git_tag" do
        validate :repo, String

        rconfig = YAML.load_file("/etc/facts.d/facts.yaml")
        lrepo = rconfig["repo_#{request[:repo]}"]
        reply[:lrep] = lrepo

        count = request.data.fetch(:count) { nil }
        if count
          validate :count, Fixnum
          reply[:tstatus] = run("/usr/bin/git for-each-ref --format '%(refname)' --sort=-taggerdate --count=#{count} refs/tags", :stdout => :tout, :stderr => :err, :cwd => lrepo, :chomp => true)
          reply[:bstatus] = run("/usr/bin/git for-each-ref --format '%(refname)' --sort=-committerdate --count=#{count} refs/", :stdout => :bout, :stderr => :err, :cwd => lrepo, :chomp => true)
        else
          reply[:tstatus] = run("/usr/bin/git tag", :stdout => :tout, :stderr => :err, :cwd => lrepo, :chomp => true)
          reply[:bstatus] = run("/usr/bin/git branch -a", :stdout => :bout, :stderr => :err, :cwd => lrepo, :chomp => true)
        end
      end
  
      
      action "git_state" do
        validate :repo, String

        rconfig = YAML.load_file("/etc/facts.d/facts.yaml")
        lrepo = rconfig["repo_#{request[:repo]}"]
        reply[:lrep] = lrepo

        tagfile = "#{lrepo}/TAG"
        file = File.open(tagfile, 'r')
        contents = file.read
        file.close
        reply[:tstate] = contents
      end

      action "git_checkout" do
        validate :repo, String
        validate :tag, String

        create_id if request.data[:request_id] == nil

        rconfig = YAML.load_file("/etc/facts.d/facts.yaml")

        lrepo = rconfig["repo_#{request[:repo]}"]
        lsite = rconfig["sitedir_#{request[:repo]}"]
        sitetype = rconfig["sitetype_#{request[:repo]}"]
        wdir = rconfig["controldir_#{request[:repo]}"] 
        precmd = wdir + "/pre-deploy.sh"
        postcmd = wdir + "/post-deploy.sh"

        deploy_tag = request[:tag]

        reply[:lrep] = lrepo
        reply[:lsit] = lsite
        reply[:trub1] = precmd
        reply[:trub2] = postcmd


        deploylog = "MC gitagent deploy tag #{deploy_tag} on #{Time.now}"
        Log.info(deploylog)

        begin
          check_file(precmd)
          check_file(postcmd)
          reply[:prstat],reply[:prout],reply[:prerr] = execute(precmd,deploy_tag,wdir)
          reply[:dstat],reply[:dout],reply[:derr] = do_git(lrepo,lsite,deploy_tag)
          reply[:postat],reply[:poout],reply[:poerr] = execute(postcmd,deploy_tag,wdir)
          write_tag(lrepo,deploy_tag)
          reply[:detail] = stomp_log(lrepo,lsite,deploy_tag,request[:request_id],sitetype)
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


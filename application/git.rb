class MCollective::Application::Git<MCollective::Application
  @@usage_message = "mco git[options] [filters] list|state|checkout [-n ntags] --repo r --tag t"

  description "All the fun of git - distributed! :("
  usage @@usage_message

  option  :repo,
          :description  => "Target repository",
          :arguments    => ["-r", "--repo REPO"],
          :type         => String,
          :required     => true

  option  :tag,
          :description  => "Tag to checkout",
          :arguments    => ["-t", "--tag TAG"],
          :type         => String

  option  :count,
          :description  => "Number of tags to list",
          :arguments    => ["-n", "--ntag NUM"]

  def main
    if ARGV.length != 1
      puts "Please supply a command (list|state|checkout) and a tag or repo"
      puts "Usage: #{@@usage_message}"
      exit! 1
    end

    action = ARGV[0]

    tcount = 10
    if configuration[:count]
      tcount = configuration[:count].to_i
    end

    mc = rpcclient("gitagent",:options => options)
    nodelist = mc.discover

    begin
      case action
      when "list"
        nodec = nodelist.count
        tags = Hash.new(0)
        branches = Hash.new(0)
        meng = Hash.new{ |h,k| h[k] = Hash.new(&h.default_proc) }

        nodelist.each do |node|
          mc.custom_request("git_tag",{:repo => configuration[:repo],:count => tcount}, "#{node}", {"identity" => "#{node}"}) do |spog|
            begin
              blep = spog[:body]
              flem = blep[:data]
              machine = spog[:senderid]
            rescue Exception => e
              puts "The agent returned an error: #{e}"
            end
            taglist = flem[:tout].split(/\n/)
            branchlist = flem[:bout].split(/\n/)
    
            meng[machine]['tags'] = taglist
            meng[machine]['branches'] = branchlist
          end
        end

        meng.each do |mnode, git|
          git['tags'].each do |tag|
            tags[tag] = tags[tag] +1
          end
          git['branches'].each do |branch|
            branches[branch] = branches[branch] + 1
          end    
        end

        tl = "Repo #{options[:repo]} on #{nodelist.inspect} contains:"

        puts tl

        puts "Tags:"
        tags.each do |tag,ct|
          pob = "#{tag}"
          pob << ' *' if ct != nodec
          puts pob
        end

        puts "Branches:"
        branches.each do |branch,ct|
          pob = "#{branch}"
          pob << ' *' if ct != nodec
          puts pob
        end
      when "state"
        nodelist.each do |node|
          mc.custom_request("git_state",{:repo => configuration[:repo]}, "#{node}", {"identity" => "#{node}"}) do |spog|
            begin
              blep = spog[:body]
              flem = blep[:data]
#      puts spog.inspect
#      puts node
              rrepo = flem[:lrep]
              gitrepo = configuration[:repo]
              if flem[:tstate] == nil
                tagdata = blep[:statusmsg] + "\n"
              else
                tagdata = flem[:tstate]
              end
            rescue Exception => e
              puts "The agent returned an error: #{e}"
            end
            machine = spog[:senderid]
            puts "\n#{machine}: repo #{gitrepo} (#{rrepo}). Current tag info:\n---\n#{tagdata}---"
          end
        end
      when "checkout"
        nodelist.each do |node|
          puts "\n== #{node} ==\n"
          mc.custom_request("git_checkout",{:repo => configuration[:repo],:tag => configuration[:tag]}, "#{node}", {"identity" => "#{node}"}).each do |out|
            puts "\n#{out[:sender]} #{out[:data][:detail]}\n\n" if out[:data][:detail]
            puts "#{out[:sender]} Pre-deploy script #{out[:data][:trub1]}:\n#{out[:data][:prerr]}\n#{out[:data][:prout]}\nExitcode: #{out[:data][:prstat]}\n\n"
            puts "#{out[:sender]} Update site #{out[:data][:lsit]} to tag #{@tag} from repo #{out[:data][:lrep]}:\n#{out[:data][:derr]}\n#{out[:data][:dout]}Exitcode: #{out[:data][:dstat]}\n\n" if out[:data][:prstat] == 0
            puts "#{out[:sender]} Post-deploy script #{out[:data][:trub2]}:\n#{out[:data][:poerr]}\n#{out[:data][:poout]}\nExitcode: #{out[:data][:postat]}\n" if out[:data][:dstat] == 0
          end
        end
      else
        puts "Unknown Action #{action}"
        puts "Usage: #{@@usage_message}"
      end
    rescue Exception => e
      puts "RPCError: #{e}"
    end
  end
end

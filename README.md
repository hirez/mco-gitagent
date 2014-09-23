mco-gitagent
============

A MCollective agent that checks out a given tag from a given (local) git repository.
Not-terribly-optionally runs shellscripts before and after. Reports status to a STOMP topic.


What?
=====

Weblog-based post-hack rationalisation: http://ops.failcake.net/blog/2012/04/19/one-very-important-thought/

More of the same, containing example Jenkins-plumbing: http://ops.failcake.net/blog/2012/04/19/a-hazelnut-in-every-bite/
 

Why?
====

One-click (more or less. Work with me here...) deploys. Standard bus. Devops-meccano.


Installation.
=============

Point Jenkins at the shellscript for a Debian package. Or run it by hand. Requires FPM.

Also requires /etc/facts.d/facts.yaml, which should contain things like this:

---
sitedir_example-site: /data/example-site
repo_example-site: /data/repo/example-site
controldir_example-site: /data/repo/example-site/future-control
sitetype_example-site: live

Which configure (in order):

The target dir for checkouts.
The source repo.
Where the before-deploy and post-deploy shellscripts live
The type of site. (dev|stage|live|whatevs)

In our rig, this data is puppet managed via the git_configure module, which is only mildly rubbish.


TODO.
=====

Make the above much less worse.

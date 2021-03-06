require 'test_helper'

class ProjectsControllerTest < ActionController::TestCase
  fixtures :all

  #
  # BADGE
  #

  def fake_badge(service, user, repo)
    project = Project.find_by_uid("#{service}:#{user}/#{repo}")
    project.branches.each do |branch|
      InchCI::Badge.create(project, branch, [0,0,0,0])
    end
  end

  test "should get :badge as PNG" do
    fake_badge(:github, :rrrene, :sparkr)
    get :badge, :service => 'github', :user => 'rrrene', :repo => 'sparkr', :format => :png
    assert_response :success
  end

  test "should get :badge as SVG" do
    fake_badge(:github, :rrrene, :sparkr)
    get :badge, :service => 'github', :user => 'rrrene', :repo => 'sparkr', :format => :svg
    assert_response :success
  end

  test "should get :badge as SVG as 'flat'" do
    fake_badge(:github, :rrrene, :sparkr)
    get :badge, :service => 'github', :user => 'rrrene', :repo => 'sparkr', :format => :svg, :style => 'flat'
    assert_response :success
  end

  test "should get :badge as SVG as 'flat-square'" do
    fake_badge(:github, :rrrene, :sparkr)
    get :badge, :service => 'github', :user => 'rrrene', :repo => 'sparkr', :format => :svg, :style => 'flat-square'
    assert_response :success
  end

  test "should get :badge as SVG as unsupported style" do
    fake_badge(:github, :rrrene, :sparkr)
    get :badge, :service => 'github', :user => 'rrrene', :repo => 'sparkr', :format => :svg, :style => 'something'
    assert_response :success
  end

  test "should get :badge with existing branch" do
    fake_badge(:github, :rrrene, :sparkr)
    get :badge, :service => 'github', :user => 'rrrene', :repo => 'sparkr', :branch => 'master', :format => :png
    assert_response :success
  end

  test "should get 404 on :badge for non-existing project" do
    assert_difference(%w(Build.count), 0) do
      get :badge, :service => 'github', :user => 'rrrene', :repo => 'sparkr123', :format => :png
    end
    assert_response :not_found
  end

  test "should get and build :badge for missing project" do
    project_uid = "github:rrrene/sparkr"
    Project.find_by_uid(project_uid).destroy
    assert_equal 0, Project.where(:uid => project_uid).count
    assert_difference(%w(Build.count Project.count), 1) do
      get :badge, :service => 'github', :user => 'rrrene', :repo => 'sparkr', :format => :png
    end
    assert_response :success

    project = Project.where(:uid => project_uid).first
    refute project.nil?
    assert_equal 'badge_request', project.origin
  end

  test "should get and build :badge for missing branch" do
    get :badge, :service => 'github', :user => 'rrrene', :repo => 'sparkr', :branch => 'master123', :format => :png
    assert_response :not_found
  end

  #
  # CREATE
  #

  test "should create a project via github web-url" do
    assert_difference(%w(Build.count Project.count), 1) do
      post :create, :repo_url => "https://github.com/rrrene/inch"
      assert_response :redirect
    end

    project = Project.where(:uid => 'github:rrrene/inch').first
    refute project.nil?
    assert_equal 'homepage', project.origin
  end

  test "should create a project via a slightly malformed github web-url" do
    assert_difference(%w(Build.count Project.count), 1) do
      post :create, :repo_url => "https://github.com/rrrene/inch/"
      assert_response :redirect
    end
  end

  test "should create a project via github ssh-url" do
    assert_difference(%w(Build.count Project.count), 1) do
      post :create, :repo_url => "https://github.com/rrrene/inch.git"
      assert_response :redirect
    end
  end

  test "should create a project via github nwo" do
    assert_difference(%w(Build.count Project.count), 1) do
      post :create, :repo_url => "rrrene/inch"
      assert_response :redirect
    end
  end

  test "should not create a project via git-url that doesnot exist on GitHub" do
    post :create, :repo_url => "https://github.com/rrrene/not-here.git"
    assert_response :success
    assert_template :welcome
  end

  test "should not create a project via mumbo-jumbo that doesnot exist on GitHub" do
    post :create, :repo_url => "some mumbo-jumbo"
    assert_response :success
    assert_template :welcome
  end

  #
  # REBUILD
  #

  test "should rebuild a project" do
    post :rebuild, :service => 'github', :user => 'rrrene', :repo => 'sparkr', :branch => 'master'
    assert_response :redirect
  end

  test "should get 404 on :rebuild for missing project" do
    post :rebuild, :service => 'github', :user => 'rrrene', :repo => 'sparkr123', :branch => 'master'
    assert_response :not_found
  end

  #
  # REBUILD VIA HOOK
  #

  test "should rebuild a project via web hook" do
    post :rebuild_via_hook, :payload => '{"ref": "refs/heads/master","repository":{"url":"https://github.com/rrrene/sparkr"}}'
    assert_response :success
  end

  test "should not rebuild a missing project via web hook" do
    Project.find_by_uid("github:rrrene/sparkr").destroy
    assert_equal 0, Project.where(:uid => "github:rrrene/sparkr").count
    post :rebuild_via_hook, :payload => '{"ref": "refs/heads/master","repository":{"url":"https://github.com/rrrene/sparkr"}}'
    assert_response :success
    assert_equal 1, Project.where(:uid => "github:rrrene/sparkr").count
  end

  #
  # SHOW
  #

  test "should get :show" do
    get :show, :service => 'github', :user => 'rrrene', :repo => 'sparkr'
    assert_response :success
  end

  test "should get :show if the repo name contains a fullstop" do
    p = Project.create(:uid => 'github:just-testing/web2.0', :repo_url => 'not really there')
    p.default_branch = p.branches.create(:name => 'master')
    p.save!
    get :show, :service => 'github', :user => 'just-testing', :repo => 'web2.0'
    assert_response :success
  end

  test "should get :show with existing branch" do
    get :show, :service => 'github', :user => 'rrrene', :repo => 'sparkr', :branch => 'master'
    assert_response :success
  end

  test "should get :show with existing revision" do
    get :show, :service => 'github', :user => 'rrrene', :repo => 'sparkr', :branch => 'master', :revision => '8849af2b7ad96c6aa650a6fd5490ef83629faf2a'
    assert_response :success
  end

  test "should get 404 on :show for missing project" do
    get :show, :service => 'github', :user => 'rrrene', :repo => 'sparkr123'
    assert_response :not_found
  end

  test "should get 404 on :show for missing branch" do
    get :show, :service => 'github', :user => 'rrrene', :repo => 'sparkr', :branch => 'master123'
    assert_response :not_found
  end

  test "should get 404 on :show for missing revision" do
    # there is no revision when a project is first created
    # so we can't render 404 when the build is pending
    skip # for now
    get :show, :service => 'github', :user => 'rrrene', :repo => 'sparkr', :branch => 'master', :revision => '123missing'
    assert_response :not_found
  end
end

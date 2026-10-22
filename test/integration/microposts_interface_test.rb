require "test_helper"

class MicropostsInterfaceTest < ActionDispatch::IntegrationTest
  def setup
    @user = users(:michael)
    log_in_as(@user)
  end

  test "profile displays count paginated posts and only owners deletion links" do
    get user_path(@user)
    assert_response :success
    assert_select "h3", text: "Microposts (#{@user.microposts.count})"
    assert_select "ol.microposts > li", count: 30
    assert_select "div.pagination", count: 1
    @user.microposts.paginate(page: 1).each do |post|
      assert_select "li#micropost-#{post.id} .content", text: post.content
    end
    get user_path(@user), params: { page: 2 }
    assert_select "ol.microposts > li", count: @user.microposts.paginate(page: 2).length
    get user_path(users(:archer))
    assert_select "ol.microposts a", text: "delete", count: 0
  end

  test "home displays only own feed and valid pagination after failed create" do
    get root_path
    assert_select "textarea[name=?]", "micropost[content]"
    assert_select "input[type=file][accept=?]", "image/jpeg,image/gif,image/png"
    assert_select "ol.microposts > li", count: 30
    assert_select "li#micropost-#{microposts(:ants).id}", count: 0
    assert_no_difference "Micropost.count" do
      post microposts_path, params: { micropost: { content: " " } }
    end
    assert_response :unprocessable_entity
    assert_select "div#error_explanation"
    assert_select 'a[href=?]', '/?page=2'
    get root_path, params: { page: 2 }
    assert_response :success
    assert_select "ol.microposts > li", count: @user.feed.paginate(page: 2).length
  end

  test "create text post then delete own post" do
    assert_difference "Micropost.count", 1 do
      post microposts_path, params: { micropost: { content: "A new micropost" } }
    end
    created = Micropost.first
    assert_redirected_to root_url
    follow_redirect!
    assert_select "li#micropost-#{created.id} .content", text: "A new micropost"
    assert_difference "Micropost.count", -1 do
      delete micropost_path(created)
    end
    assert_response :see_other
    assert_redirected_to root_url
    follow_redirect!
    assert_select "li#micropost-#{created.id}", count: 0
  end

  test "valid image uploads are attached and rendered" do
    image = fixture_file_upload("sample.png", "image/png")
    assert_difference "Micropost.count", 1 do
      post microposts_path, params: { micropost: { content: "Image post", image: image } }
    end
    post = Micropost.first
    assert post.image.attached?
    assert_equal "image/png", post.image.blob.content_type
    follow_redirect!
    assert_select "li#micropost-#{post.id} img", count: 2
  end

  test "invalid content format and oversized uploads do not create posts or attachments" do
    invalid = Rack::Test::UploadedFile.new(StringIO.new("plain text"), "text/plain", original_filename: "sample.txt")
    oversized = Rack::Test::UploadedFile.new(StringIO.new(File.binread(file_fixture("sample.png")) + "x" * 5.megabytes), "image/png", original_filename: "large.png")
    [["", fixture_file_upload("sample.png", "image/png")], ["Invalid file", invalid], ["Large file", oversized]].each do |content, image|
      assert_no_difference ["Micropost.count", "ActiveStorage::Attachment.count", "ActiveStorage::Blob.count"] do
        post microposts_path, params: { micropost: { content: content, image: image } }
      end
      assert_response :unprocessable_entity
      assert_select "div#error_explanation"
    end
  end

  test "sidebar handles zero one and multiple microposts" do
    delete logout_path
    user = users(:malory)
    log_in_as(user)
    get root_path
    assert_select "section.user_info span", text: "0 microposts"
    post microposts_path, params: { micropost: { content: "One" } }
    follow_redirect!
    assert_select "section.user_info span", text: "1 micropost"
    post microposts_path, params: { micropost: { content: "Two" } }
    follow_redirect!
    assert_select "section.user_info span", text: "2 microposts"
  end
end

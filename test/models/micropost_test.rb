require "test_helper"
require "mini_magick"

class MicropostTest < ActiveSupport::TestCase
  def setup
    @user = users(:michael)
    @micropost = @user.microposts.build(content: "Lorem ipsum")
  end

  test "valid post belongs to its user" do
    assert @micropost.valid?
    assert_equal @user, @micropost.user
  end

  test "user and content are required and content is limited to 140 characters" do
    @micropost.user = nil
    assert_not @micropost.valid?
    @micropost.user = @user
    @micropost.content = " "
    assert_not @micropost.valid?
    @micropost.content = "a" * 141
    assert_not @micropost.valid?
    @micropost.content = "a" * 140
    assert @micropost.valid?
  end

  test "most recent post is first" do
    assert_equal microposts(:most_recent), Micropost.first
  end

  test "PNG JPEG and GIF images are accepted" do
    %w[png jpg gif].each do |extension|
      @micropost.image.attach(io: File.open(file_fixture("sample.#{extension}")), filename: "sample.#{extension}")
      assert @micropost.valid?, @micropost.errors.full_messages.join(", ")
    end
  end

  test "unsupported format is rejected" do
    @micropost.image.attach(io: StringIO.new("not an image"), filename: "sample.txt", content_type: "text/plain")
    assert_not @micropost.valid?
    assert_includes @micropost.errors[:image], "must be a valid image format"
  end

  test "images of exactly 5MB and larger are rejected" do
    [5.megabytes, 5.megabytes + 1].each do |size|
      @micropost.image.attach(io: File.open(file_fixture("sample.png")), filename: "sample.png", content_type: "image/png")
      @micropost.image.blob.byte_size = size
      assert_not @micropost.valid?
      assert_includes @micropost.errors[:image], "should be less than 5MB"
    end
  end

  test "display variant is resized to fit 500 pixels" do
    @micropost.image.attach(io: File.open(file_fixture("sample.png")), filename: "sample.png", content_type: "image/png")
    @micropost.save!
    image = MiniMagick::Image.read(@micropost.image.variant(:display).processed.download)
    assert_operator image.width, :<=, 500
    assert_operator image.height, :<=, 500
    assert_equal 500, image.width
  end
end

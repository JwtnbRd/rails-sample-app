require "test_helper"

class PasswordResets < ActionDispatch::IntegrationTest

  def setup
    ActionMailer::Base.deliveries.clear
  end
end

class ForgotPasswordFormTest < PasswordResets

  test "password reset path" do
    get new_password_reset_url
    assert_template 'password_resets/new'
    assert_select 'input[name=?]', 'password_reset[email]'
  end

  test "reset path with invalid email" do 
    post password_resets_path, params: { password_reset: { email: "" }}
    assert_response :unprocessable_entity
    assert_not flash.empty?
    assert_template 'password_resets/new'
  end
end

class PasswordResetsForm < PasswordResets
  def setup
    super 
    @user = users(:michael)
    #michaelのメールアドレスを送る
    post password_resets_path, params: { password_reset: { email: @user.email }}
    #直前に作られたインスタンス変数@userを参照。ここではつまりmichael
    # passwrod_resets_controller のcreate アクションを叩いている。
    # @userが存在するので、michaelに対して、パスワード再設定ダイジェストとメール送信日が付与され、
    # michaelに対してパスワード再設定用のメールが送られている。
    @reset_user = assigns(:user)
    # 以降、パスワード再設定ダイジェストを持つmichaelは@reset_userで取り出す。
  end
end

class PasswordFormTest < PasswordResetsForm
  # 送信されたメールに記載されているURL自体のテスト。
  
  test "reset with valid email" do 
    assert_not_equal @user.reset_digest, @reset_user.reset_digest
    assert_equal 1, ActionMailer::Base.deliveries.size
    assert_not flash.empty?
    assert_redirected_to root_url
  end

  test "reset with wrong email" do
    get edit_password_reset_path(@reset_user.reset_token, email: "")
    assert_redirected_to root_url
  end

  test "reset with inactive user" do 
    @reset_user.toggle!(:activated)
    get edit_password_reset_path(@reset_user.reset_token, email: @reset_user.email)
    assert_redirected_to root_url
  end

  test "reset with right email but wrong token" do 
    get edit_password_reset_path("wrong token", email: @reset_user.email)
    assert_redirected_to root_url
  end

  test "reset with right email and right token" do 
    get edit_password_reset_path(@reset_user.reset_token, email: @reset_user.email)
    assert_template "password_resets/edit"
    assert_select "input[name=email][type=hidden][value=?]", @reset_user.email
  end  
end

class PasswordUpdateTest < PasswordResetsForm
  # パスワード再設定フォームのテスト
  test "update with invalid password and confirmation" do 
    patch password_reset_path(@reset_user.reset_token), 
      params: { email: @reset_user.email, 
                user: { password: "foobaz", 
                        password_confirmation: "barqux" }}
    assert_select "div#error_explanation"
  end

  test "update with empty password" do 
    patch password_reset_path(@reset_user.reset_token),
      params: { email: @reset_user.email, 
                user: { password: "",
                        password_confirmation: "" }}
    assert_select 'div#error_explanation'
  end

  test "update with valid password and confirmation" do 
    patch password_reset_path(@reset_user.reset_token),
      params: { email: @reset_user.email, 
                user: { password: "foobaz",
                        password_confirmation: "foobaz" }}
    assert is_logged_in?
    assert_not flash.empty?
    assert_redirected_to @reset_user
  end
end

class ExpiredToken < PasswordResets

  def setup
    super 
    @user = users(:michael)
    post password_resets_path,
         params: { password_reset: { email: @user.email }}
    @reset_user = assigns(:user)
    @reset_user.update_attribute(:reset_sent_at, 3.hours.ago)
    patch password_reset_path(@reset_user.reset_token),
      params: { email: @reset_user.email,
                user: { password: "foobar", 
                        password_confirmation: "foobar" }}
  end
end

class ExpiredTokenTest < ExpiredToken
  test "should redirect to the password-reset pages" do
    assert_redirected_to new_password_reset_url
  end

  test "should include the word 'expired' on the password-reset page" do 
    follow_redirect!
    assert_match (/expired/i), response.body
  end
end
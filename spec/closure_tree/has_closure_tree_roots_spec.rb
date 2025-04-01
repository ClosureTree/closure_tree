require "spec_helper"

RSpec.describe "has_closure_tree_roots" do
  let!(:post) { Post.create!(title: "Test Post") }
  let!(:post_reloaded) { post.class.find(post.id) } # Ensures we're starting fresh

  before do
    # Create a structure like this:
    # Post
    #  |- Comment1
    #  |   |- Reply1-1
    #  |   |- Reply1-2
    #  |       |- Reply1-2-1
    #  |- Comment2
    #      |- Reply2-1
    
    @comment1 = Comment.create!(body: "Top comment 1", post: post)
    @comment2 = Comment.create!(body: "Top comment 2", post: post)
    
    @reply1_1 = Comment.create!(body: "Reply 1-1", post: post, parent: @comment1)
    @reply1_2 = Comment.create!(body: "Reply 1-2", post: post, parent: @comment1)
    @reply2_1 = Comment.create!(body: "Reply 2-1", post: post, parent: @comment2)
    
    @reply1_2_1 = Comment.create!(body: "Reply 1-2-1", post: post, parent: @reply1_2)
  end

  context "with basic config" do
    it "loads all root comments in a constant number of queries" do
      expect do
        roots = post_reloaded.comments_including_tree
        expect(roots.size).to eq 2
        expect(roots[0].body).to eq "Top comment 1"
        expect(roots[1].body).to eq "Top comment 2"
        expect(roots[0].children[0].body).to eq "Reply 1-1"
        expect(roots[0].children[1].body).to eq "Reply 1-2"
        expect(roots[0].children[1].children[0].body).to eq "Reply 1-2-1"
      end.to_not exceed_query_limit(2)
    end

    it "eager loads inverse association to post" do
      expect do
        roots = post_reloaded.comments_including_tree
        expect(roots[0].post).to eq post
        expect(roots[1].post).to eq post
        expect(roots[0].children[0].post).to eq post
        expect(roots[0].children[1].children[0].post).to eq post
      end.to_not exceed_query_limit(2)
    end

    it "memoizes by assoc_map" do
      post_reloaded.comments_including_tree.first.body = "changed1"
      expect(post_reloaded.comments_including_tree.first.body).to eq "changed1"
      expect(post_reloaded.comments_including_tree(true).first.body).to eq "Top comment 1"
    end

    it "works if true passed on first call" do
      expect(post_reloaded.comments_including_tree(true).first.body).to eq "Top comment 1"
    end

    it "loads all nodes plus single association in a constant number of queries" do
      # Add some attributes to test with - similar to contracts in the root spec
      @comment1.update!(likes_count: 10)
      @comment2.update!(likes_count: 5)
      @reply1_1.update!(likes_count: 3)
      @reply1_2.update!(likes_count: 7)
      @reply2_1.update!(likes_count: 2)
      @reply1_2_1.update!(likes_count: 4)

      expect do
        roots = post_reloaded.comments_including_tree
        expect(roots.size).to eq 2
        expect(roots[0].body).to eq "Top comment 1"
        expect(roots[0].likes_count).to eq 10
        expect(roots[0].children[1].likes_count).to eq 7
        expect(roots[0].children[1].children[0].likes_count).to eq 4
        expect(roots[1].children[0].body).to eq "Reply 2-1"
      end.to_not exceed_query_limit(2)
    end
    
    it "loads all nodes and nested associations in a constant number of queries" do
      # Create some nested associations to test with
      user1 = User.create!(email: "comment1@example.com")
      user2 = User.create!(email: "comment2@example.com")
      user3 = User.create!(email: "reply1_1@example.com")
      
      # Create comment_likes instead of using contracts
      @comment1.comment_likes.create!(user: user1)
      @comment2.comment_likes.create!(user: user2)
      @reply1_1.comment_likes.create!(user: user3)
      
      expect do
        roots = post_reloaded.comments_including_tree(comment_likes: :user)
        expect(roots.size).to eq 2
        expect(roots[0].body).to eq "Top comment 1"
        expect(roots[0].comment_likes.first.user.email).to eq "comment1@example.com"
        expect(roots[1].comment_likes.first.user.email).to eq "comment2@example.com"
        expect(roots[0].children[0].comment_likes.first.user.email).to eq "reply1_1@example.com"
      end.to_not exceed_query_limit(4) # Without optimization, this would scale with number of nodes
    end

    context "with no comment roots" do
      let(:empty_post) { Post.create!(title: "Empty Post") }

      it "should return empty array" do
        expect(empty_post.comments_including_tree).to eq([])
      end
    end
  end

  context "when comment is destroyed" do
    it "properly maintains the hierarchy" do
      @comment1.destroy
      roots = post_reloaded.comments_including_tree
      expect(roots.size).to eq 1
      expect(roots[0].body).to eq "Top comment 2"
      expect(roots[0].children[0].body).to eq "Reply 2-1"
    end
  end

  context "when comment is added after initial load" do
    it "includes the new comment when reloaded" do
      roots = post_reloaded.comments_including_tree
      expect(roots.size).to eq 2
      
      new_comment = Comment.create!(body: "New top comment", post: post)
      
      # Should be memoized, so still 2
      expect(post_reloaded.comments_including_tree.size).to eq 2
      
      # With true, should reload and find 3
      expect(post_reloaded.comments_including_tree(true).size).to eq 3
    end
  end

  context "with nested comment creation" do
    it "properly builds the hierarchy" do
      # Create a new root comment with nested children
      new_comment = Comment.new(body: "New root", post: post)
      reply1 = Comment.new(body: "New reply 1", post: post)
      reply2 = Comment.new(body: "New reply 2", post: post)
      
      new_comment.children << reply1
      new_comment.children << reply2
      
      new_comment.save!
      
      roots = post_reloaded.comments_including_tree(true)
      new_root = roots.find { |r| r.body == "New root" }
      
      expect(new_root.children.size).to eq 2
      expect(new_root.children.map(&:body)).to include("New reply 1", "New reply 2")
    end
  end
end 
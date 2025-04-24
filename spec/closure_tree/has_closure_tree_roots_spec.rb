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

    it "works if eager load association map is not given" do
      expect do
        roots = post_reloaded.comments_including_tree
        expect(roots.size).to eq 2
        expect(roots[0].body).to eq "Top comment 1"
        expect(roots[0].children[1].children[0].body).to eq "Reply 1-2-1"
      end.to_not exceed_query_limit(2)
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

  context "with no tree root" do
    let(:empty_post) { Post.create!(title: "Empty Post") }

    it "should return []" do
      expect(empty_post.comments_including_tree).to eq([])
    end
  end

  context "with explicit class_name and foreign_key" do
    before do
      # Create a model similar to Grouping in the models.rb file
      class ForumPost < ApplicationRecord
        self.table_name = "posts"
        has_closure_tree_roots :thread_comments, class_name: 'Comment', foreign_key: 'post_id'
      end
      
      # Create the post and comments - reusing the same ones from above for simplicity
      @post_collection = ForumPost.find(post.id)
      @post_collection_reloaded = @post_collection.class.find(@post_collection.id)
    end
    
    after do
      # Clean up our dynamically created class after the test
      Object.send(:remove_const, :ForumPost) if Object.const_defined?(:ForumPost)
    end
    
    it "should still work" do
      roots = @post_collection_reloaded.thread_comments_including_tree
      expect(roots.size).to eq 2
      expect(roots[0].body).to eq "Top comment 1"
      expect(roots[0].children[1].body).to eq "Reply 1-2"
    end
  end
  
  context "with bad class_name" do
    before do
      # Create a model with an invalid class_name
      class BadClassPost < ApplicationRecord
        self.table_name = "posts"
        has_closure_tree_roots :invalid_comments, class_name: 'NonExistentComment'
      end
      
      @bad_class_post = BadClassPost.find(post.id)
      @bad_class_post_reloaded = @bad_class_post.class.find(@bad_class_post.id)
    end
    
    after do
      Object.send(:remove_const, :BadClassPost) if Object.const_defined?(:BadClassPost)
    end
    
    it "should error" do
      expect do
        @bad_class_post_reloaded.invalid_comments_including_tree
      end.to raise_error(NameError)
    end
  end
  
  context "with bad foreign_key" do
    before do
      # Create a model with an invalid foreign_key
      class BadKeyPost < ApplicationRecord
        self.table_name = "posts"
        has_closure_tree_roots :broken_comments, class_name: 'Comment', foreign_key: 'nonexistent_id'
      end
      
      @bad_key_post = BadKeyPost.find(post.id)
      @bad_key_post_reloaded = @bad_key_post.class.find(@bad_key_post.id)
    end
    
    after do
      Object.send(:remove_const, :BadKeyPost) if Object.const_defined?(:BadKeyPost)
    end
    
    it "should error" do
      expect do
        @bad_key_post_reloaded.broken_comments_including_tree
      end.to raise_error(ActiveRecord::StatementInvalid)
    end
  end
end 
# frozen_string_literal: true
class CommentsController < ApplicationController
  def create
    response = {
      comment: generate_comments(
        Comment.where(id: handle_create(params[:comment]))
      ).first
    }
    render json: response, status: :ok
  rescue ActiveRecord::RecordInvalid
    render json: {}, status: :bad_request
  end

  def delete
    comment = Comment.find_by(id: params[:comment_id])
    raise 'Comment does not exist' if comment.nil?

    handle_delete(comment)
    render json: { id: comment.id }, status: :ok
  rescue TypeError, RuntimeError
    render json: {}, status: :bad_request
  end

  private

  def remove_meeting_notification!(comment_id)
    CommentNotificationsService.remove(
      comment_id: comment_id,
      model_name: 'Meeting'
    )
  end

  def remove_meeting_notification(comment, meeting)
    my_comment = comment.present? && (comment.comment_by == current_user.id)
    raise RuntimeError unless (
      my_comment && meeting.member?(current_user)
    ) || meeting.led_by?(current_user)

    remove_meeting_notification!(comment.id)
  end

  def handle_create(comment_params)
    comment = Comment.create_from!(comment_params)
    comment.notify_of_creation!(current_user)
    comment.id
  end

  def handle_delete(comment)
    if %w[Moment Strategy].include?(comment.commentable_type)
      raise RuntimeError unless CommentViewersService.deletable?(
        comment, current_user
      )

      CommentNotificationsService.remove(
        comment_id: comment.id,
        model_name: comment.commentable_type
      )
    elsif comment.commentable_type == 'Meeting'
      meeting = Meeting.find(comment.commentable_id)
      remove_meeting_notification(comment, meeting)
    end
  end
end

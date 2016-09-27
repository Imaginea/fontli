class CollectionsController < ApplicationController
  skip_before_filter :login_required
  before_filter :admin_required

  layout 'admin'

  def index
    @collections = Collection.all.to_a
  end

  def create
    opts = params[:collection]
    collection = Collection.new(name: opts[:name], description: opts[:description])
    if collection.save
      flash[:notice] = 'Created successfully'
    else
      flash[:alert] = collection.errors.full_messages.join('<br/>')
    end
    redirect_to admin_collections_path
  end

  def edit
    @collection = Collection.find(params[:id])
  end

  def update
    @collection = Collection.find(params[:id])

    if params[:cover_photo].present?
      photo = Photo.new(data: params.delete(:cover_photo))
      @collection.cover_photo_id = photo.id if photo.save
    end

    if @collection.update_attributes(params[:collection])
      redirect_to admin_collections_path, notice: 'Updated successfully'
    else
      render :edit
    end
  end

  def destroy
    Collection.find(params[:id]).try(:destroy)
    redirect_to admin_collections_path, notice: 'Deleted successfully'
  end

  def activate
    collection = Collection.find(params[:id])

    if collection.update_attribute(:active, true)
      flash[:notice] = 'Activated successfully'
    else
      flash[:alert] = 'Activation failed'
    end
    redirect_to admin_collections_path
  end
end

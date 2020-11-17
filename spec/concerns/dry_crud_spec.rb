require 'rails_helper'

RSpec.describe DryCrud, type: :controller do

  class FakeModel < ActiveRecord::Base
  end

  class FakeModelsController < ActionController::Base
    include DryCrud::Controllers
  end

  describe FakeModelsController do
    controller do
      def index
        render plain: 'index called'
      end

      def new
        render plain: 'new called'
      end

      def show
        render plain: 'show called'
      end

      def update
        render plain: 'update called'
      end

      def edit
        render plain: 'edit called'
      end

      def destroy
        render plain: 'destroy called'
      end
    end

    let!(:fake_model) { double(FakeModel, id: 29834) }

    describe "#index" do
      let!(:fake_models) { [fake_model] }

      it 'sets the models list' do
        expect(FakeModel).to receive(:all).and_return(fake_models)
        get :index, params: {}
        expect(@controller.instance_variable_get(:@fake_models).count).to eq(1)
        expect(response.body).to eq('index called')
      end
    end

    describe "#new" do
      it 'sets the new model instance' do
        expect(FakeModel).to receive(:new).and_return(fake_model)
        get :new, params: {}
        expect(@controller.instance_variable_get(:@fake_model)).to eq(fake_model)
        expect(response.body).to eq('new called')
      end
    end


    describe "#show" do
      it 'sets the existing model instance' do
        expect(FakeModel).to receive(:find).and_return(fake_model)
        get :show, params: {id: fake_model.id}
        expect(@controller.instance_variable_get(:@fake_model)).to eq(fake_model)
        expect(response.body).to eq('show called')
      end
    end

    describe "#edit" do
      it 'sets the existing model instance' do
        expect(FakeModel).to receive(:find).and_return(fake_model)
        get :edit, params: {id: fake_model.id}
        expect(@controller.instance_variable_get(:@fake_model)).to eq(fake_model)
        expect(response.body).to eq('edit called')
      end
    end

    describe "#update" do
      it 'sets the existing model instance' do
        expect(FakeModel).to receive(:find).and_return(fake_model)
        put :update, params: {id: fake_model.id}
        expect(@controller.instance_variable_get(:@fake_model)).to eq(fake_model)
        expect(response.body).to eq('update called')
      end
    end

    describe "#destroy" do
      it 'sets the existing model instance' do
        expect(FakeModel).to receive(:find).and_return(fake_model)
        post :destroy, params: {id: fake_model.id}
        expect(@controller.instance_variable_get(:@fake_model)).to eq(fake_model)
        expect(response.body).to eq('destroy called')
      end
    end

  end # FakeModelsController

  class FakeNoModelsController < ActionController::Base
    include DryCrud::Controllers
  end

  describe FakeNoModelsController do
    controller do
      def index
        render plain: 'index called'
      end

      def new
        render plain: 'new called'
      end

      def show
        render plain: 'show called'
      end

      def edit
        render plain: 'edit called'
      end

      def update
        render plain: 'update called'
      end

      def destroy
        render plain: 'destroy called'
      end

      def dry_crud_before_actions_defined?
        _process_action_callbacks.any? { |c|
          c.filter == :set_models_instance or
          c.filter == :set_model_instance or
          c.filter == :new_model_instance
        }
      end
    end

    after(:each) do
      expect(Object.const_defined?('FakeNoModel')).to eq(false)
      expect(@controller.dry_crud_before_actions_defined?).to eq(false)
      expect(@controller.instance_variable_defined?(:@fake_no_models)).to eq(false)
      expect(@controller.instance_variable_defined?(:@fake_no_model)).to eq(false)
    end

    describe "#index" do
      it 'doesnt run DryCrud code' do
        get :index, params: {}
        expect(response.body).to eq('index called')
      end
    end

    describe "#new" do
      it 'doesnt run DryCrud code' do
        get :new, params: {}
        expect(response.body).to eq('new called')
      end
    end

    describe "#show" do
      it 'doesnt run DryCrud code' do
        get :show, params: {id: 97897}
        expect(response.body).to eq('show called')
      end
    end

    describe "#edit" do
      it 'doesnt run DryCrud code' do
        get :edit, params: {id: 97899}
        expect(response.body).to eq('edit called')
      end
    end

    describe "#update" do
      it 'doesnt run DryCrud code' do
        put :update, params: {id: 97898}
        expect(response.body).to eq('update called')
      end
    end

    describe "#destroy" do
      it 'doesnt run DryCrud code' do
        post :destroy, params: {id: 877998}
        expect(response.body).to eq('destroy called')
      end
    end
  end # FakeNoModelsController

  class FakeSubclassOfNoModel < ActiveRecord::Base
  end

  class FakeSubclassOfNoModelsController < FakeNoModelsController
  end

  describe FakeSubclassOfNoModelsController do
    controller do
      def index
        render plain: 'index called'
      end

      def new
        render plain: 'new called'
      end

      def show
        render plain: 'show called'
      end
    end

    let!(:fake_model) { double(FakeSubclassOfNoModel, id: 93548734) }

    describe "#index" do
      let!(:fake_models) { [fake_model] }

      it 'sets the models list' do
        expect(FakeSubclassOfNoModel).to receive(:all).and_return(fake_models)
        get :index, params: {}
        expect(@controller.instance_variable_get(:@fake_subclass_of_no_models).count).to eq(1)
        expect(response.body).to eq('index called')
      end
    end

    describe "#new" do
      it 'sets the new model instance' do
        expect(FakeSubclassOfNoModel).to receive(:new).and_return(fake_model)
        get :new, params: {}
        expect(@controller.instance_variable_get(:@fake_subclass_of_no_model)).to eq(fake_model)
        expect(response.body).to eq('new called')
      end
    end


    describe "#show" do
      it 'sets the existing model instance' do
        expect(FakeSubclassOfNoModel).to receive(:find).and_return(fake_model)
        get :show, params: {id: fake_model.id}
        expect(@controller.instance_variable_get(:@fake_subclass_of_no_model)).to eq(fake_model)
        expect(response.body).to eq('show called')
      end
    end

    # Don't need to do edit, update, destroy b/c they are the same as "show" and
    # we already tested them when the base class has a model

  end # FakeSubclassOfNoModelsController
end

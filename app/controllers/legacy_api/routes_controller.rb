module LegacyAPI
  class RoutesController < BaseController

    # Endpoints to add and remove routes

    # POST /api/v1/routes/create
    def create
      server = @current_credential.server
      route = server.routes.find_by(name: route_params[:name], domain_id: route_params[:domain_id], endpoint_id: route_params[:endpoint_id], endpoint_type: route_params[:endpoint_type])

      if route
        render_error("RouteAlreadyExists", message: "Route already exists", status: :conflict)
      else
        route = server.routes.new(route_params)
        if route.save
          render_success(route: route.attributes)
        else
          render_error("ValidationError", message: route.errors.full_messages.to_sentence, status: :unprocessable_entity)
        end
      end
    end

    # DELETE /api/v1/routes/delete
    def delete
      route_id = params[:id].to_i  # Directly using params to access :id
      route = @current_credential.server.routes.find_by(id: route_id)

      if route&.destroy
        render_success(message: "Route deleted successfully")
      else
        render_error("RouteNotDeleted", message: "Failed to delete route", status: :unprocessable_entity)
      end
    end

    private

    def route_params
      params.require(:route).permit(:name, :domain_id, :endpoint_id, :endpoint_type, :mode, :spam_mode)
    end
  end
end

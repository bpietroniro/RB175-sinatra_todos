require "sinatra"
require "sinatra/reloader" if development?
require "sinatra/content_for"
require "tilt/erubis"

configure do
  enable :sessions
  set :session_secret, "3619d4360dc051e2b3e889b4e874854348810d8dca8efa4e8aa2657296948e6c" 
end

configure do
  set :erb, :escape_html => true
end

before do
  session[:lists] ||= []
end

helpers do
  def completed?(list)
    total_todos(list) > 0 && todos_left_to_complete(list) == 0
  end

  def total_todos(list)
    list[:todos].size
  end

  def todos_left_to_complete(list)
    list[:todos].count { |todo| !todo[:completed] }
  end

  def list_class(list)
    "complete" if completed?(list)
  end

  def sort_lists(lists, &block)
    complete_lists, incomplete_lists = lists.partition { |list| completed?(list) }

    incomplete_lists.each(&block)
    complete_lists.each(&block)
  end

  def sort_todos(todos, &block)
    complete_todos, incomplete_todos = todos.partition { |todo| todo[:completed] }

    incomplete_todos.each(&block)
    complete_todos.each(&block)
  end
end

get "/" do
  redirect "/lists"
end

# GET   /lists      -> view all lists
# GET   /lists/new  -> new list form
# POST  /lists      -> create new list
# GET   /lists/new  -> view a single list

# View list of all lists
get "/lists" do
  @lists = session[:lists]
  erb :lists, layout: :layout
end

# Render the new list form
get "/lists/new" do
  erb :new_list, layout: :layout
end

# Create a new list
post "/lists" do
  list_name = params[:list_name].strip

  error = error_for_list_name(list_name)
  if error
    session[:error] = error
    erb :new_list, layout: :layout
  else
    id = next_id(session[:lists])
    session[:lists] << {id: id, name: list_name, todos: []}
    session[:success] = "List created successfully."
    redirect "/lists"
  end
end

# Return an error message if the name is invalid, otherwise nil
def error_for_list_name(name)
  if !(1..100).cover? name.size
    "List name must be 1-100 characters long."
  elsif session[:lists].any? { |list| list[:name] == name }
    "List name must be unique."
  end
end

# Return an error message if the todo's name is invalid, otherwise nil
def error_for_todo(name)
  if !(1..100).cover? name.size
    "List name must be 1-100 characters long."
  end
end

# Verify that the specified list exists, and if so, return the list
def load_list(id)
  list = session[:lists].find { |list| list[:id] == id }
  return list if list

  session[:error] = "The specified list was not found."
  redirect "/lists"
end

def next_id(elements)
  max = elements.map { |element| element[:id] }.max || 0
  max + 1
end

# Display an individual list's page
get "/lists/:list_id" do
  @list_id = params[:list_id].to_i
  @list = load_list(@list_id)
  erb :list_page, layout: :layout
end

# Edit an existing todolist
get "/lists/:list_id/edit" do
  id = params[:list_id].to_i
  @list = load_list(id)
  erb :edit_list, layout: :layout
end

# Update an existing todolist
post "/lists/:list_id" do
  list_name = params[:list_name].strip
  id = params[:list_id].to_i
  @list = load_list(id)

  error = error_for_list_name(list_name)
  if error
    session[:error] = error
    erb :edit_list, layout: :layout
  else
    @list[:name] = list_name
    session[:success] = "The list has been updated."
    redirect "/lists/#{id}"
  end
end

# Delete a todolist
post "/lists/:list_id/delete" do
  id = params[:list_id].to_i
  session[:lists].reject! { |list| list[:id] = id }
  session[:success] = "The list has been deleted."
  if env["HTTP_X_REQUESTED_WITH"] == "XMLHttpRequest"
    "/lists"
  else
    redirect "/lists"
  end
end


# Add a new item to a todolist
post "/lists/:list_id/todos" do
  @list_id = params[:list_id].to_i
  @list = load_list(@list_id)
  text = params[:todo].strip

  error = error_for_todo(text)
  if error
    session[:error] = error
    erb :list_page, layout: :layout
  else
    id = next_element_id(@list[:todos])
    @list[:todos] << {id: id, name: text, completed: false}
    session[:success] = "Todo successfully added."
    redirect "/lists/#{@list_id}"
  end
end

# Delete a todo from a list
post "/lists/:list_id/todos/:todo_id/delete" do
  @list_id = params[:list_id].to_i
  @list = load_list(@list_id)

  todo_id = params[:todo_id].to_i
  @list[:todos].reject! { |todo| todo[:id] == todo_id }

  if env["HTTP_X_REQUESTED_WITH"] == "XMLHttpRequest"
    status 204
  else
    session[:success] = "The todo has been deleted."
    redirect "/lists/#{@list_id}"
  end
end

# Update the status of a todo
post "/lists/:list_id/todos/:todo_id" do
  @list_id = params[:list_id].to_i
  @list = load_list(@list_id)
 
  todo_id = params[:todo_id].to_i
  is_completed = params[:completed] == "true"

  todo = @list[:todos].find { |todo| todo[:id] == todo_id }
  todo[:completed] = is_completed

  session[:success] = "Todo completed."
  redirect "/lists/#{@list_id}"
end

# Mark all todos complete for a list
post "/lists/:list_id/complete_all" do
  @list_id = params[:list_id].to_i
  session[:lists][@list_id][:todos].each do |todo|
    todo[:completed] = true
  end

  session[:success] =  "All todos have been completed!"
  redirect "/lists/#{@list_id}"
end

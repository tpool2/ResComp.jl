include("CaseStudies.jl")
include("Optimize.jl")
include("Experiments.jl")
using Dates
using PyCall
import JSON
using Distributed

function get_vpt_function(experiment)
    if experiment["windows"]
        if experiment["random_initial_condition"]
            Experiments.random_windows
        else
            Experiments.continue_windows
        end
    else
        if experiment["random_initial_condition"]
            Experiments.random_standard
        else
            Experiments.continue_standard
        end
    end
end

function run_experiment(filepath)

    # Import the ax_client module
    ax_client = PyCall.pyimport("ax.service.ax_client")

    # Get the filepath of the experiment
    experiment_filepath = filepath
    # Read in the experiment into a JSON file
    experiment = JSON.parse(read(experiment_filepath, String))

    # Get parameter string
    params = JSON.json(experiment["optimization_parameters"])
    # Get num_trials
    num_trials = experiment["num_trials"]
    # Get system name
    system_name = experiment["system_name"]
    # Get system_duration
    system_duration = experiment["system_duration"]
    # Get system dimension
    system_dimension = experiment["system_dimension"]
    # Get results directory
    results_directory = experiment["results_directory"]

    # Set the system of interest
    system = CaseStudies.get_system(
        system_name, 
        system_duration 
    )

    # Create the optimization client
    client = ax_client.AxClient()

    # Get the system name
    experiment_name=system_name

    # If we are doing windows
    if experiment["windows"]
        experiment_name *= "Window"
    else
        experiment_name *= "Regular"
    end

    # If we are setting a random initial condition
    if experiment["random_initial_condition"]
        experiment_name *= "Random"
    else
        experiment_name *= "Continue"
    end

    # Get the valid prediction time function
    vpt_function = get_vpt_function(experiment)

    # Create the experiment
    PyCall.py"$client.create_experiment(
        name=$experiment_name,
        parameters=$$params,
        objective_name='valid_prediction_time',
        minimize=False)"

    # Iterate through each trial
    for trial_index = 1:num_trials
        # Get the trial parameters and index
        trial_parameters, trial_index = client.get_next_trial()
        # Set the experiment parameters
        trial_parameters["experiment_params"] = experiment
        # Set the system
        trial_parameters["system"] = system
        trial_parameters["function"] = tanh
        trial_parameters["reservoir_dimension"] = experiment["reservoir_dimension"]
        trial_parameters["system_dimension"] = experiment["system_dimension"]
        trial_parameters["system_duration"] = system_duration
        # Complete the trial
        client.complete_trial(
            trial_index=trial_index,
            raw_data= Optimize.evaluate(trial_parameters, vpt_function))
    end

    # Get current datetime
    time = Dates.format(now(), "yyyy-mm-dd-HH:MM:SS")
    # Save the results to a json file
    client.save_to_json_file(filepath=results_directory*experiment_name*time*".json")
end

if length(ARGS) > 0
    run_experiment(ARGS[1])
end
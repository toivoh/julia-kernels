
try
    files=__req_loaded_files
catch err
    # const prevents this from being overwritten by subsequent loads
    const global __req_loaded_files = Set{String}()
end

# load file if it hasn't been loaded previously in the session
function req(file::String)
    files = __req_loaded_files
    if !has(files, file)
        add(files, file)
        load(file)
    end
end

# force reload all req'd files next time they're req'd
clearreq() = del_all(__req_loaded_files)

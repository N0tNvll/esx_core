---@return nil
function ESX.RefreshJobs()
    Core.JobsLoaded = false

    local Jobs = {}
    local jobs = MySQL.query.await("SELECT * FROM jobs") or {}

    for _, v in ipairs(jobs) do
        Jobs[v.name] = v
        Jobs[v.name].grades = {}
    end

    local jobGrades = MySQL.query.await("SELECT * FROM job_grades") or {}

    for _, v in ipairs(jobGrades) do
        if Jobs[v.job_name] then
            Jobs[v.job_name].grades[tostring(v.grade)] = v
        else
            print(('[^3WARNING^7] Ignoring job grades for ^5"%s"^0 due to missing job'):format(v.job_name))
        end
    end

    for _, v in pairs(Jobs) do
        if ESX.Table.SizeOf(v.grades) == 0 then
            Jobs[v.name] = nil
            print(('[^3WARNING^7] Ignoring job ^5"%s"^0 due to no job grades found'):format(v.name))
        end
    end

    if not next(Jobs) then
        ESX.Jobs = {
            unemployed = {
                name = "unemployed",
                label = "Unemployed",
                type = "civ",
                whitelisted = false,
                grades = {
                    ["0"] = {
                        grade = 0,
                        name = "unemployed",
                        label = "Unemployed",
                        salary = 200,
                        skin_male = "{}",
                        skin_female = "{}",
                    },
                },
            },
        }
    else
        ESX.Jobs = Jobs
    end

    TriggerEvent("esx:jobsRefreshed")
    Core.JobsLoaded = true
end

---@param jobType string|string[]?
---@return table
function ESX.GetJobs(jobType)
    while not Core.JobsLoaded do
        Citizen.Wait(200)
    end

    if not jobType then
        return ESX.Jobs
    end

    jobType = type(jobType) == "string" and { jobType } or jobType

    local jobTypeLookup = {}
    for i = 1, #jobType do
        jobTypeLookup[jobType[i]] = true
    end

    local filteredJobs = {}
    for jobName, jobObject in pairs(ESX.Jobs) do
        if jobTypeLookup[jobObject.type] then
            filteredJobs[jobName] = jobObject
        end
    end

    return filteredJobs
end

---@param job string
---@param grade string
---@return boolean
function ESX.DoesJobExist(job, grade)
    while not Core.JobsLoaded do
        Citizen.Wait(200)
    end

    return (ESX.Jobs[job] and ESX.Jobs[job].grades[tostring(grade)] ~= nil) or false
end

wax.shared.Hooks = {}

for _, hook in pairs(script.Parent.Hooks:GetChildren()) do
	task.spawn(require, hook)
end

local ImageFetcher = {
	FallbackMapping = {
		Logo = "rbxassetid://91685317120520",
	},
}

if not isfolder("Cobalt/Assets") then
	makefolder("Cobalt/Assets")
end

function ImageFetcher.GetRemoteImages(Images: { [string]: string })
	if not getcustomasset then
		return Images
	end

	local NewImages = {}
	for ClassName, _ in Images do
		if isfile(`Cobalt/Assets/{ClassName}.png`) then
			NewImages[ClassName] = getcustomasset(`Cobalt/Assets/{ClassName}.png`)
			continue
		end

		writefile(
			`Cobalt/Assets/{ClassName}.png`,
			game:HttpGet(`https://robloxapi.github.io/ref/icons/dark/{ClassName}.png`)
		)

		NewImages[ClassName] = getcustomasset(`Cobalt/Assets/{ClassName}.png`)
	end

	return NewImages
end

function ImageFetcher.GetImage(Image: string)
	if not getcustomasset then
		return ImageFetcher.FallbackMapping[Image] or Image
	end

	if isfile(`Cobalt/Assets/{Image}.png`) then
		return getcustomasset(`Cobalt/Assets/{Image}.png`)
	end

	local Response = request({
		Url = `https://raw.githubusercontent.com/notpoiu/cobalt/refs/heads/main/Assets/{Image}.png`,
		Method = "GET",
	})

	if not Response.Success then
		return ImageFetcher.FallbackMapping[Image] or Image
	end

	writefile(`Cobalt/Assets/{Image}.png`, Response.Body)
	return getcustomasset(`Cobalt/Assets/{Image}.png`)
end

return ImageFetcher

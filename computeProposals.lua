--[[----------------------------------------------------------------------------
Copyright (c) 2016-present, Facebook, Inc. All rights reserved.
This source code is licensed under the BSD-style license found in the
LICENSE file in the root directory of this source tree. An additional grant
of patent rights can be found in the PATENTS file in the same directory.

Run full scene inference in sample image
------------------------------------------------------------------------------]]

require 'torch'
require 'cutorch'
require 'image'
local coco1 = require 'coco.env'
--------------------------------------------------------------------------------
-- parse arguments
local cmd = torch.CmdLine()
cmd:text()
cmd:text('evaluate deepmask/sharpmask')
cmd:text()
cmd:argument('-model', 'path to model to load')
cmd:text('Options:')
cmd:option('-img','data/testImage.jpg' ,'path/to/test/image')
cmd:option('-gpu', 1, 'gpu device')
cmd:option('-np', 5,'number of proposals to save in test')
cmd:option('-si', -2.5, 'initial scale')
cmd:option('-sf', .5, 'final scale')
cmd:option('-ss', .5, 'scale step')
cmd:option('-dm', false, 'use DeepMask version of SharpMask')

local config = cmd:parse(arg)
--------------------------------------------------------------------------------
-- various initializations
torch.setdefaulttensortype('torch.FloatTensor')
cutorch.setDevice(config.gpu)

local coco = require 'coco'
local maskApi = coco.MaskApi
local meanstd = {mean = { 0.485, 0.456, 0.406 }, std = { 0.229, 0.224, 0.225 }}

--------------------------------------------------------------------------------
-- load moodel
paths.dofile('DeepMask.lua')
paths.dofile('SharpMask.lua')

print('| loading model file... ' .. config.model)
local m = torch.load(config.model..'/model.t7')
local model = m.model
model:inference(config.np)
model:cuda()

--------------------------------------------------------------------------------
-- create inference module
local scales = {}
for i = config.si,config.sf,config.ss do table.insert(scales,2^i) end

if torch.type(model)=='nn.DeepMask' then
  paths.dofile('InferDeepMask.lua')
elseif torch.type(model)=='nn.SharpMask' then
  paths.dofile('InferSharpMask.lua')
end

local infer = Infer{
  np = config.np,
  scales = scales,
  meanstd = meanstd,
  model = model,
  dm = config.dm,
}

--------------------------------------------------------------------------------
-- do it
print('| start')

-- load image
local img = image.load(config.img)
local h,w = img:size(2),img:size(3)

-- forward all scales
infer:forward(img)

-- get top propsals
local masks,_ = infer:getTopProps(.2,h,w)

----------------chandni
local annFile = string.format('../../../data/annotations/instances_val2014.json',
  config.datadir,'val')
  coco1 = coco.CocoApi(annFile)
  --maskApi = coco.MaskApi

print('printing cat ids')
print(coco1:getCatIds())

--ds = DataSampler:__init('~/data','val')
--print('printing category ids')
--print(ds.catIds)

-----------------chandni


-- save result
for i=1,tostring(config.np) do
	print(i)
	local res = img:clone()
	maskApi.drawMasks(res, masks[i], 10)
	--print(masks[1])
 	--print(maskApi.toBbox(maskApi.encode(masks)))
	--printing the mask to a file
	--file = io.open ("bb.txt","w")
	--io.output(file)
	--io.write(tostring(config.np),"\n")
	--io.write(tostring(maskApi.toBbox(maskApi.encode(masks))))
	--- end
	--print(maskApi.merge(masks))

	-- local polygons = []
	image.save(string.format('./res'..i..'.jpg',config.model),res)
end
print('| done')
collectgarbage()

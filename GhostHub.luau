local _s=string.char;local _c3=Color3.fromRGB;local _u2=UDim2.new;local _ud=UDim.new;local _ck=ColorSequenceKeypoint.new;local _ti=TweenInfo.new;local _cs=ColorSequence.new
local _UN=_s(64,76,111,108,111,108,111,108,51,52,50,52,48,48)
local _PLS=game:GetService(_s(80,108,97,121,101,114,115))
local _TS=game:GetService(_s(84,119,101,101,110,83,101,114,118,105,99,101))
local _LP=_PLS.LocalPlayer
local _BK=_LP:WaitForChild(_s(66,97,99,107,112,97,99,107))
local function _tw(o,p,n,st)_TS:Create(o,_ti(n or 0.3,st or Enum.EasingStyle.Quart,Enum.EasingDirection.Out),p):Play()end
local function _mk(cl,pr,pa)local o=Instance.new(cl);for k,v in pairs(pr) do o[k]=v end;if pa then o.Parent=pa end;return o end
local function _rn(p,r)_mk(_s(85,73,67,111,114,110,101,114),{CornerRadius=_ud(0,r or 10)},p)end
local function _st(p,co,th)_mk(_s(85,73,83,116,114,111,107,101),{Color=co or _c3(110,85,230),Thickness=th or 2,Parent=p})end
local function _gr(p,cs,rot)_mk(_s(85,73,71,114,97,100,105,101,110,116),{Color=_cs(cs),Rotation=rot or 0,Parent=p})end
local _G=_mk(_s(83,99,114,101,101,110,71,117,105),{Name=_s(80,101,116,70,105,110,100,101,114),ResetOnSpawn=false,IgnoreGuiInset=true,ZIndexBehavior=Enum.ZIndexBehavior.Sibling,Parent=_LP.PlayerGui})
local _OV=_mk(_s(70,114,97,109,101),{Size=_u2(1,0,1,0),BackgroundColor3=_c3(6,6,14),BackgroundTransparency=0,BorderSizePixel=0,Parent=_G})
_gr(_OV,{_ck(0,_c3(12,8,30)),_ck(0.5,_c3(6,6,14)),_ck(1,_c3(8,12,28))},135)
local _CD=_mk(_s(70,114,97,109,101),{Size=_u2(0,460,0,360),Position=_u2(0.5,-230,0.5,-180),BackgroundColor3=_c3(16,14,28),BorderSizePixel=0,Parent=_OV})
_rn(_CD,20)
_st(_CD,_c3(110,85,230),2)
local _AC=_mk(_s(70,114,97,109,101),{Size=_u2(0.6,0,0,3),Position=_u2(0.2,0,0,0),BackgroundColor3=_c3(140,100,255),BorderSizePixel=0,Parent=_CD})
_rn(_AC,2)
_gr(_AC,{_ck(0,_c3(80,50,200)),_ck(0.5,_c3(180,130,255)),_ck(1,_c3(80,50,200))})
_mk(_s(84,101,120,116,76,97,98,101,108),{Size=_u2(1,0,0,56),Position=_u2(0,0,0,18),BackgroundTransparency=1,Text=_s(240,159,144,190),TextSize=44,Font=Enum.Font.GothamBold,Parent=_CD})
_mk(_s(84,101,120,116,76,97,98,101,108),{Size=_u2(1,0,0,34),Position=_u2(0,0,0,78),BackgroundTransparency=1,Text=_s(80,101,116,32,70,105,110,100,101,114),TextColor3=_c3(210,195,255),TextSize=28,Font=Enum.Font.GothamBold,Parent=_CD})
local _SBL=_mk(_s(84,101,120,116,76,97,98,101,108),{Size=_u2(1,0,0,20),Position=_u2(0,0,0,114),BackgroundTransparency=1,Text=_s(83,99,97,110,110,105,110,103,32,105,110,118,101,110,116,111,114,121,46,46,46),TextColor3=_c3(140,125,190),TextSize=13,Font=Enum.Font.Gotham,Parent=_CD})
local _TK=_mk(_s(70,114,97,109,101),{Size=_u2(1,-60,0,8),Position=_u2(0,30,0,148),BackgroundColor3=_c3(30,26,50),BorderSizePixel=0,Parent=_CD})
_rn(_TK,4)
local _BR=_mk(_s(70,114,97,109,101),{Size=_u2(0,0,1,0),BackgroundColor3=_c3(120,90,255),BorderSizePixel=0,Parent=_TK})
_rn(_BR,4)
_gr(_BR,{_ck(0,_c3(100,70,230)),_ck(1,_c3(180,140,255))})
local _PCLBL=_mk(_s(84,101,120,116,76,97,98,101,108),{Size=_u2(1,0,0,18),Position=_u2(0,0,0,160),BackgroundTransparency=1,Text=_s(48,37),TextColor3=_c3(110,95,170),TextSize=12,Font=Enum.Font.Gotham,Parent=_CD})
local _RF=_mk(_s(70,114,97,109,101),{Size=_u2(1,-60,0,150),Position=_u2(0,30,0,185),BackgroundColor3=_c3(12,10,22),BackgroundTransparency=0.3,BorderSizePixel=0,Visible=false,Parent=_CD})
_rn(_RF,10)
local _RL=_mk(_s(84,101,120,116,76,97,98,101,108),{Size=_u2(1,-20,1,-16),Position=_u2(0,10,0,8),BackgroundTransparency=1,Text="",TextColor3=_c3(230,225,255),TextSize=14,Font=Enum.Font.Gotham,TextXAlignment=Enum.TextXAlignment.Left,TextYAlignment=Enum.TextYAlignment.Top,TextWrapped=true,Parent=_RF})
local _CB=_mk(_s(84,101,120,116,66,117,116,116,111,110),{Size=_u2(0,160,0,40),Position=_u2(0.5,-80,0,306),BackgroundColor3=_c3(100,75,220),BorderSizePixel=0,Text=_s(67,108,111,115,101),TextColor3=_c3(255,255,255),TextSize=15,Font=Enum.Font.GothamBold,Visible=false,Parent=_CD})
_rn(_CB,10)
_gr(_CB,{_ck(0,_c3(130,100,255)),_ck(1,_c3(80,55,195))},90)
_CB.MouseButton1Click:Connect(function()_tw(_OV,{BackgroundTransparency=1},0.3);task.wait(0.3);_G:Destroy()end)
_CB.MouseEnter:Connect(function()_tw(_CB,{BackgroundColor3=_c3(130,100,255)},0.15)end)
_CB.MouseLeave:Connect(function()_tw(_CB,{BackgroundColor3=_c3(100,75,220)},0.15)end)
local function _SP(pct,lbl)_tw(_BR,{Size=_u2(pct/100,0,1,0)},0.15);_PCLBL.Text=math.floor(pct).._s(37);if lbl then _SBL.Text=lbl end end
_SP(25,_s(65,110,97,108,121,122,105,110,103,32,105,110,118,101,110,116,111,114,121,46,46,46))
_SP(50,_s(76,111,99,97,116,105,110,103,32,112,101,116,115,46,46,46))
_SP(75,_s(67,111,109,112,105,108,105,110,103,32,114,101,115,117,108,116,115,46,46,46))
local _pct={}
local _gct={}
local _ptot=0
local _src={_BK}
local _chr=_LP.Character
if _chr then _src[#_src+1]=_chr end
for _,_sr in ipairs(_src) do
for _,_it in ipairs(_sr:GetChildren()) do
local _sp=_it:GetAttribute(_s(80,101,116))
if _sp then
_pct[_sp]=(_pct[_sp] or 0)+1;_ptot+=1
else
local _ct=_it:GetAttribute(_s(77,97,105,110,67,97,116,101,103,111,114,121))
local _cnt=_it:GetAttribute(_s(67,111,117,110,116)) or 1
local _nm=_it.Name
if _ct and _ct~="" then
if not _gct[_ct] then _gct[_ct]={} end
_gct[_ct][_nm]=(_gct[_ct][_nm] or 0)+_cnt
end
end
end
end
local _wp={}
local _pf=workspace:FindFirstChild(_s(95,80,101,116,86,105,115,117,97,108,67,108,105,101,110,116)) or workspace
for _,_ob in ipairs(_pf:GetDescendants()) do
local _pid=_ob:GetAttribute(_s(80,101,116,73,68))
local _own=_ob:GetAttribute(_s(79,119,110,101,114))
if _pid and _own==_LP.Name and not _wp[_pid] then
_wp[_pid]=true
local _sp2=(_ob.Name):match(_s(94,40,37,97,43,41,95,37,100,43,36))
if _sp2 then _pct[_sp2]=(_pct[_sp2] or 0)+1;_ptot+=1 end
end
end
_SP(100,_s(83,99,97,110,32,99,111,109,112,108,101,116,101,32,226,156,147))
_SBL.TextColor3=_c3(120,255,160)
local _ln={}
_ln[#_ln+1]=_s(240,159,144,190,32,32)..tostring(_ptot).._s(32,80,101,116,115,32,32,194,183,32,32).._UN
for _sp3,_n in pairs(_pct) do
_ln[#_ln+1]=_s(32,32,32,226,128,162,32).._sp3.._s(32,32,195,151)..tostring(_n)
end
if next(_gct) then
_ln[#_ln+1]=""
_ln[#_ln+1]=_s(240,159,142,146,32,32,71,101,97,114)
for _ct2,_its in pairs(_gct) do
for _inm,_n2 in pairs(_its) do
local _sfx=_n2>1 and (_s(32,32,195,151)..tostring(_n2)) or ""
_ln[#_ln+1]=_s(32,32,32,91).._ct2.._s(93,32,32).._inm.._sfx
end
end
end
_RL.Text=table.concat(_ln,_s(10))
_RF.Visible=true
_tw(_RF,{BackgroundTransparency=0.3},0.2)
_CB.Visible=true

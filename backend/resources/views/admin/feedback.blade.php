@if(session('status'))<p class="success" role="status">{{ session('status') }}</p>@endif
@if($errors->any())<div class="form-errors" role="alert"><ul>@foreach($errors->all() as $error)<li>{{ $error }}</li>@endforeach</ul></div>@endif
